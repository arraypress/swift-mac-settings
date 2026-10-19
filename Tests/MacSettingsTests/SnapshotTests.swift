//
//  SnapshotTests.swift
//  MacSettingsTests
//
//  Created by David Sherlock on 2026.
//
//
//  snapshot → change → diff → apply → undo, on the scratch domain.
//

import Foundation
import Testing
@testable import MacSettings

struct SnapshotTests {

    /// Three scratch settings: a bool, a float and a string with choices.
    private func trio(_ f: Fixture) -> (Catalogue, Setting, Setting, Setting) {
        let a = f.setting("flag", defaultValue: .bool(false), restart: [.finder])
        let b = f.setting("delay", type: .float, min: 0, max: 5, defaultValue: .double(0.5))
        let c = f.setting("format", type: .string, choices: [Choice(value: .string("png"), label: "PNG"),
                                                             Choice(value: .string("jpg"), label: "JPEG")],
                          defaultValue: .string("png"))
        return (f.catalogue([a, b, c]), a, b, c)
    }

    @Test func aSnapshotRoundTripsThroughJSON() throws {
        let f = try Fixture()
        let (catalogue, a, b, _) = trio(f)
        f.store.write(.bool(true), to: a.place)
        f.store.write(.real(0.25), to: b.place)
        let snapshot = Snapshots.take(catalogue, context: f.context())
        #expect(snapshot.macOS == "27.0.1")
        #expect(snapshot.takenAt != nil)
        let back = try Snapshots.decode(Snapshots.encode(snapshot))
        #expect(back == snapshot)
        let json = String(decoding: Snapshots.encode(snapshot), as: UTF8.self)
        #expect(json.contains(#""value" : 0.25"#))
        #expect(json.contains(#""kind" : "settings-snapshot""#))
    }

    @Test func diffAgainstNowNamesWhatChanged() throws {
        let f = try Fixture()
        let (catalogue, a, b, c) = trio(f)
        let before = Snapshots.take(catalogue, context: f.context())
        f.store.write(.bool(true), to: a.place)
        f.store.write(.string("jpg"), to: c.place)
        f.store.write(.real(0.5), to: b.place)   // set, but to the default: not a change
        let (changes, notCompared) = Differ.diff(before, Snapshots.take(catalogue, context: f.context()), catalogue: catalogue)
        #expect(changes.map(\.id) == [a.id, c.id])
        #expect(changes.first?.from == "off" && changes.first?.to == "on")
        #expect(changes.last?.to == "JPEG")
        #expect(notCompared.isEmpty)
    }

    @Test func idsOnlyOneSideRecordedAreNotDrift() throws {
        let f = try Fixture()
        let (catalogue, _, _, _) = trio(f)
        let now = Snapshots.take(catalogue, context: f.context())
        let old = Snapshot(settings: Array(now.settings.dropLast()) + [SnapshotSetting(id: "gone.setting", value: .bool(true))])
        let (changes, notCompared) = Differ.diff(old, now, catalogue: catalogue)
        #expect(changes.isEmpty)
        #expect(Set(notCompared) == [now.settings.last!.id, "gone.setting"])
    }

    @Test func applyPlansWritesNothingThenRestoresTheSnapshot() throws {
        let f = try Fixture()
        let (catalogue, a, b, c) = trio(f)
        f.store.write(.real(1), to: b.place)
        let wanted = Snapshots.take(catalogue, context: f.context())
        f.store.write(.bool(true), to: a.place)
        f.store.write(.real(2), to: b.place)
        f.store.write(.string("jpg"), to: c.place)

        let plan = Planner.planApply(wanted, catalogue: catalogue, context: f.context())
        #expect(plan.map(\.status) == [.change, .change, .change])
        #expect(f.store.read(a.place) == .bool(true), "the plan wrote nothing")

        let outcomes = try Applier.apply(plan, context: f.context())
        #expect(outcomes.allSatisfy { $0.result == .applied })
        #expect(f.store.read(a.place) == .absent, "not set in the snapshot: removed")
        #expect(f.store.read(b.place) == .real(1))
        #expect(f.store.read(c.place) == .absent)
        #expect(Differ.diff(wanted, Snapshots.take(catalogue, context: f.context()), catalogue: catalogue).changes.isEmpty)

        let undone = try Undoer.undo(nil, context: f.context())
        #expect(undone.count == 3 && undone.allSatisfy { $0.result == .restored })
        #expect(f.store.read(a.place) == .bool(true))
        #expect(f.store.read(b.place) == .real(2))
        #expect(f.store.read(c.place) == .string("jpg"))
    }

    @Test func applySkipsWhatItMayNotWriteAndSaysWhy() throws {
        let f = try Fixture()
        let ok = f.setting("ok")
        let readOnly = f.setting("ro", writable: false)
        let locked = f.setting("locked")
        let unverified = f.setting("unverified", verified: ["26"])
        try f.manage(scratchDomain, keys: [locked.key: true], forUser: false)
        let catalogue = f.catalogue([ok, readOnly, locked, unverified])
        let snapshot = Snapshot(settings: [
            SnapshotSetting(id: ok.id, value: .bool(true)),
            SnapshotSetting(id: readOnly.id, value: .bool(true)),
            SnapshotSetting(id: locked.id, value: .bool(true)),
            SnapshotSetting(id: unverified.id, value: .bool(true)),
            SnapshotSetting(id: "tests.from-the-future", value: .bool(true)),
            SnapshotSetting(id: ok.id + "x", value: nil, set: true),
        ])
        let plan = Planner.planApply(snapshot, catalogue: catalogue, context: f.context())
        #expect(plan.map(\.skip) == [nil, .notWritable, .locked, .unverified, .unknown, .unknown])
        #expect(plan[1].paneURL == "x-apple.systempreferences:com.apple.Desktop-Settings.extension")
        _ = try Applier.apply(plan, context: f.context())
        #expect(f.store.read(ok.place) == .bool(true))
        for s in [readOnly, locked, unverified] { #expect(f.store.read(s.place) == .absent, "\(s.id)") }
    }

    @Test func aBadValueInASnapshotIsSkippedNotWritten() throws {
        let f = try Fixture()
        let (catalogue, a, b, _) = trio(f)
        let snapshot = Snapshot(settings: [SnapshotSetting(id: a.id, value: .string("sideways")),
                                           SnapshotSetting(id: b.id, value: .double(99))])
        let plan = Planner.planApply(snapshot, catalogue: catalogue, context: f.context())
        #expect(plan.map(\.skip) == [.invalidValue, .invalidValue])
        _ = try Applier.apply(plan, context: f.context())
        #expect(f.store.read(a.place) == .absent && f.store.read(b.place) == .absent)
    }

    @Test func aHandWrittenSetupNeedsOnlyIDsAndValues() throws {
        let f = try Fixture()
        let (catalogue, a, b, _) = trio(f)
        let text = """
            {"kind": "settings-snapshot", "settings": [{"id": "\(a.id)", "value": true}, {"id": "\(b.id)", "value": 1}]}
            """
        let snapshot = try Snapshots.decode(Data(text.utf8))
        let plan = Planner.planApply(snapshot, catalogue: catalogue, context: f.context())
        #expect(plan.map(\.status) == [.change, .change])
        _ = try Applier.apply(plan, context: f.context())
        #expect(f.store.read(b.place) == .real(1))
    }

    @Test func aMalformedSnapshotIsRefused() {
        let cases = [
            #"{"kind": "something-else", "settings": []}"#,
            #"{"settings": []}"#,
            #"{"kind": "settings-snapshot", "setings": []}"#,
            #"{"kind": "settings-snapshot", "settings": [{"id": "a.b", "value": true, "vaule": 1}]}"#,
            #"{"kind": "settings-snapshot", "settings": [{"id": "a.b", "value": true}, {"id": "a.b", "value": false}]}"#,
            "not json",
        ]
        for text in cases {
            #expect(throws: SettingsError.self, "\(text)") { try Snapshots.decode(Data(text.utf8)) }
        }
    }
}
