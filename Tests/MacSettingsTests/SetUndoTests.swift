//
//  SetUndoTests.swift
//  MacSettingsTests
//
//  Created by David Sherlock on 2026.
//
//
//  set → plan, --yes → write + journal + read back, undo → exactly as before.
//  All on the scratch domain.
//

import Foundation
import Testing
@testable import MacSettings

struct SetUndoTests {

    @Test func thePlanWritesNothing() throws {
        let f = try Fixture()
        let s = f.setting("plan")
        let item = try Planner.planSet(id: s.id, value: "on", catalogue: f.catalogue([s]), context: f.context())
        #expect(item.status == .change)
        #expect(item.writes == [PlannedWrite(place: s.place, before: .absent, after: .bool(true))])
        #expect(f.store.read(s.place) == .absent)
        #expect(!FileManager.default.fileExists(atPath: f.journal.path))
    }

    @Test func applyWritesJournalsAndReadsBack() throws {
        let f = try Fixture()
        let s = f.setting("apply", restart: [.dock])
        let item = try Planner.planSet(id: s.id, value: "on", catalogue: f.catalogue([s]), context: f.context())
        let outcomes = try Applier.apply([item], context: f.context(), batch: "b1")
        #expect(outcomes.map(\.result) == [.applied])
        #expect(f.store.read(s.place) == .bool(true))
        #expect(f.defaultsRead(s.place) == "1")
        let journal = try JournalStore.load(f.journal)
        #expect(journal.count == 1)
        #expect(journal.first?.before == .absent && journal.first?.after == .bool(true))
        #expect(Restarter.needed([item]) == [.dock])
    }

    @Test func undoRestoresAnAbsentKeyAsAbsent() throws {
        let f = try Fixture()
        let s = f.setting("absent")
        let item = try Planner.planSet(id: s.id, value: "on", catalogue: f.catalogue([s]), context: f.context())
        _ = try Applier.apply([item], context: f.context())
        let undone = try Undoer.undo(nil, context: f.context())
        #expect(undone.map(\.result) == [.restored])
        #expect(f.store.read(s.place) == .absent)
        #expect(try JournalStore.load(f.journal).allSatisfy { $0.restoredAt != nil })
        #expect(throws: SettingsError.self) { try Undoer.undo(nil, context: f.context()) }
    }

    @Test func undoRestoresTheExactTypeThatWasThere() throws {
        let f = try Fixture()
        let s = f.setting("typed")
        f.store.write(.int(1), to: s.place)
        let item = try Planner.planSet(id: s.id, value: "off", catalogue: f.catalogue([s]), context: f.context())
        _ = try Applier.apply([item], context: f.context())
        #expect(f.store.read(s.place) == .bool(false))
        _ = try Undoer.undo(nil, context: f.context())
        #expect(f.store.read(s.place) == .int(1))
    }

    @Test func mirrorsAreWrittenAndRestoredWithTheMainKey() throws {
        let f = try Fixture()
        let s = f.setting("tap", storage: .int, mirrors: ["tapMirror"])
        f.store.write(.int(0), to: s.mirrors[0])
        let item = try Planner.planSet(id: s.id, value: "on", catalogue: f.catalogue([s]), context: f.context())
        #expect(item.writes.count == 2)
        _ = try Applier.apply([item], context: f.context())
        #expect(f.store.read(s.place) == .int(1) && f.store.read(s.mirrors[0]) == .int(1))
        _ = try Undoer.undo(nil, context: f.context())
        #expect(f.store.read(s.place) == .absent)
        #expect(f.store.read(s.mirrors[0]) == .int(0))
    }

    @Test func undoLeavesAKeyChangedSinceAloneUnlessForced() throws {
        let f = try Fixture()
        let s = f.setting("conflict", type: .int, defaultValue: .int(0))
        let item = try Planner.planSet(id: s.id, value: "5", catalogue: f.catalogue([s]), context: f.context())
        _ = try Applier.apply([item], context: f.context(), batch: "b")
        f.store.write(.int(7), to: s.place)
        #expect(try Undoer.undo(nil, context: f.context()).map(\.result) == [.conflict])
        #expect(f.store.read(s.place) == .int(7))
        #expect(try Undoer.undo("b", context: f.context(), force: true).map(\.result) == [.restored])
        #expect(f.store.read(s.place) == .absent)
    }

    @Test func defaultRemovesTheKeyAndUndoPutsItBack() throws {
        let f = try Fixture()
        let s = f.setting("reset", type: .string, defaultValue: .string("png"))
        f.store.write(.string("jpg"), to: s.place)
        let item = try Planner.planSet(id: s.id, value: "default", catalogue: f.catalogue([s]), context: f.context())
        #expect(item.to.contains("png"))
        _ = try Applier.apply([item], context: f.context())
        #expect(f.store.read(s.place) == .absent)
        _ = try Undoer.undo(nil, context: f.context())
        #expect(f.store.read(s.place) == .string("jpg"))
    }

    @Test func theSameValueIsUnchangedAndWritesNothing() throws {
        let f = try Fixture()
        let s = f.setting("same", defaultValue: .bool(false))
        let item = try Planner.planSet(id: s.id, value: "off", catalogue: f.catalogue([s]), context: f.context())
        #expect(item.status == .unchanged)
        #expect(try Applier.apply([item], context: f.context()).map(\.result) == [.unchanged])
        #expect(f.store.read(s.place) == .absent)
        #expect(!FileManager.default.fileExists(atPath: f.journal.path))
    }

    @Test func setRefusesWhatCannotBeWritten() throws {
        let f = try Fixture()
        let readOnly = f.setting("ro", writable: false)
        let locked = f.setting("locked")
        let unverified = f.setting("new", verified: ["26"])
        try f.manage(scratchDomain, keys: [locked.key: false])
        let catalogue = f.catalogue([readOnly, locked, unverified])
        #expect {
            try Planner.planSet(id: readOnly.id, value: "on", catalogue: catalogue, context: f.context())
        } throws: { error in
            guard case .notWritable(_, _, let pane)? = error as? SettingsError else { return false }
            return pane == "x-apple.systempreferences:com.apple.Desktop-Settings.extension"
        }
        #expect {
            try Planner.planSet(id: locked.id, value: "on", catalogue: catalogue, context: f.context())
        } throws: { error in
            if case .locked? = error as? SettingsError { return true }
            return false
        }
        #expect {
            try Planner.planSet(id: unverified.id, value: "on", catalogue: catalogue, context: f.context())
        } throws: { error in
            if case .unverified(_, let macOS)? = error as? SettingsError { return macOS == "27" }
            return false
        }
        let allowed = try Planner.planSet(id: unverified.id, value: "on", catalogue: catalogue, context: f.context(allowUnverified: true))
        #expect(allowed.status == .change)
        #expect {
            try Planner.planSet(id: "tests.nwe", value: "on", catalogue: catalogue, context: f.context())
        } throws: { error in
            if case .unknownSetting(_, let suggestions)? = error as? SettingsError { return suggestions == ["tests.new"] }
            return false
        }
        #expect(f.store.read(readOnly.place) == .absent && f.store.read(locked.place) == .absent)
    }

    @Test func applyStopsAKeyThatMovedAfterThePlan() throws {
        let f = try Fixture()
        let s = f.setting("race", type: .int, defaultValue: .int(0))
        let item = try Planner.planSet(id: s.id, value: "2", catalogue: f.catalogue([s]), context: f.context())
        f.store.write(.int(9), to: s.place)
        let outcome = try Applier.apply([item], context: f.context())
        #expect(outcome.map(\.result) == [.skipped])
        #expect(f.store.read(s.place) == .int(9))
    }

    @Test func anUnwritableJournalStopsTheWrite() throws {
        let f = try Fixture()
        let s = f.setting("nojournal")
        var context = f.context()
        let blocker = f.folder.appendingPathComponent("file")
        try Data().write(to: blocker)
        context.journal = blocker.appendingPathComponent("journal.json")
        let item = try Planner.planSet(id: s.id, value: "on", catalogue: f.catalogue([s]), context: context)
        #expect(throws: SettingsError.self) { try Applier.apply([item], context: context) }
        #expect(f.store.read(s.place) == .absent)
    }
}
