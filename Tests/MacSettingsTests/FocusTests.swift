//
//  FocusTests.swift
//  MacSettingsTests
//
//  Created by David Sherlock on 2026.
//
//  Focus against a fake: no Focus changes, no shortcut runs.
//

import AppleShortcuts
import Foundation
import Testing
@testable import MacSettings

/// A Focus that changes only when told, and maybe not even then.
final class FakeFocus: FocusHost, @unchecked Sendable {
    var active: String?
    var sets: [(name: String, on: Bool, until: String?)] = []
    /// What a set does to `active`; default: what was asked.
    var effect: ((FakeFocus, String, Bool) -> Void)? = nil
    var setError: Error?

    init(active: String? = nil) { self.active = active }

    static let modes = Data(#"""
    {"data": [{"modeConfigurations": {
      "com.apple.donotdisturb.mode.default": {"mode": {"name": "Do Not Disturb", "modeIdentifier": "com.apple.donotdisturb.mode.default", "semanticType": 0}},
      "com.apple.focus.work": {"mode": {"name": "Work", "modeIdentifier": "com.apple.focus.work"}},
      "broken": {"nomode": {}}}}]}
    """#.utf8)

    static let assertions = Data(#"""
    {"data": [{"storeAssertionRecords": [
      {"assertionStartDateTimestamp": 100, "assertionDetails": {"assertionDetailsModeIdentifier": "com.apple.focus.work",
        "assertionDetailsLifetime": {"assertionDetailsLifetimeType": "date"}}},
      {"assertionStartDateTimestamp": 200, "assertionDetails": {"assertionDetailsModeIdentifier": "com.apple.donotdisturb.mode.default",
        "assertionDetailsLifetime": {"assertionDetailsLifetimeType": "schedule"}}}]}]}
    """#.utf8)

    func modesData() -> Data? { Self.modes }
    func assertionsData() -> Data? { Self.assertions }
    func activeFocus() throws -> String? { active }
    func setFocus(name: String, on: Bool, until: String?) throws {
        sets.append((name, on, until))
        if let setError { throw setError }
        if let effect { effect(self, name, on) } else { active = on ? name : nil }
    }
}

struct FocusTests {

    @Test func modesAndTheAssertedFocusComeFromTheStoresFiles() throws {
        let modes = FocusFiles.modes(FakeFocus.modes)
        #expect(modes.map(\.name) == ["Do Not Disturb", "Work"])
        let assertion = try #require(FocusFiles.assertion(FakeFocus.assertions))
        #expect(assertion.mode == "com.apple.donotdisturb.mode.default")
        #expect(assertion.lifetime == "schedule")
        #expect(FocusFiles.assertion(Data(#"{"data": [{"storeAssertionRecords": []}]}"#.utf8)) == nil)
        #expect(FocusFiles.modes(Data("nonsense".utf8)).isEmpty)
        let reading = try Focus.read(host: FakeFocus(active: "Do Not Disturb"))
        #expect(reading.active == "Do Not Disturb")
        #expect(reading.asserted?.name == "Do Not Disturb")
        #expect(reading.lifetime == "schedule")
    }

    @Test func namesMatchExactlyThenLoosely() {
        let modes = FocusFiles.modes(FakeFocus.modes)
        #expect(FocusFiles.mode(named: "work", in: modes)?.id == "com.apple.focus.work")
        #expect(FocusFiles.mode(named: " Do Not Disturb ", in: modes)?.id == "com.apple.donotdisturb.mode.default")
        #expect(FocusFiles.mode(named: "com.apple.focus.work", in: modes)?.name == "Work")
        #expect(FocusFiles.mode(named: "Sleep", in: modes) == nil)
    }

    @Test func untilIsLocalMinutesForTheHelper() {
        let date = Date(timeIntervalSince1970: 1_792_000_000)
        #expect(FocusFiles.helperDate(date, timeZone: TimeZone(identifier: "UTC")!) == "2026-10-14 17:46")
    }

    @Test func plans() throws {
        let off = FakeFocus()
        let on = try Focus.plan(name: "work", on: true, until: nil, host: off)
        #expect(on.mode.name == "Work" && on.to == "Work" && on.from == nil && !on.unchanged)

        let working = FakeFocus(active: "Work")
        #expect(try Focus.plan(name: "Work", on: true, until: nil, host: working).unchanged)
        let later = Date().addingTimeInterval(3600)
        let extend = try Focus.plan(name: "Work", on: true, until: later, host: working)
        #expect(!extend.unchanged && extend.until == later)
        let stop = try Focus.plan(name: nil, on: false, until: nil, host: working)
        #expect(stop.mode.name == "Work" && stop.to == nil && !stop.unchanged)
        #expect(try Focus.plan(name: "Do Not Disturb", on: false, until: nil, host: working).unchanged)
        #expect(try Focus.plan(name: nil, on: false, until: nil, host: off).unchanged)
        let swap = try Focus.plan(name: "Do Not Disturb", on: true, until: nil, host: working)
        #expect(swap.from == "Work" && swap.to == "Do Not Disturb")
    }

    @Test func badPlansAreRefused() {
        let host = FakeFocus(active: "Work")
        #expect(throws: SettingsError.self) { try Focus.plan(name: "Sleep", on: true, until: nil, host: host) }
        do { _ = try Focus.plan(name: "Sleep", on: true, until: nil, host: host) } catch {
            #expect("\(error.localizedDescription)".contains("Do Not Disturb, Work"))
        }
        #expect(throws: SettingsError.self) { try Focus.plan(name: "Work", on: true, until: Date().addingTimeInterval(-5), host: host) }
        #expect(throws: SettingsError.self) { try Focus.plan(name: "Work", on: false, until: Date().addingTimeInterval(60), host: host) }
        #expect(throws: SettingsError.self) { try Focus.plan(name: nil, on: true, until: nil, host: FakeFocus()) }
    }

    @Test func applyRunsTheHelperAndBelievesOnlyTheReadBack() throws {
        let host = FakeFocus()
        let until = Date().addingTimeInterval(7200)
        let plan = try Focus.plan(name: "Work", on: true, until: until, host: host)
        let after = try Focus.apply(plan, host: host, interval: 0)
        #expect(after.active == "Work")
        #expect(host.sets.count == 1)
        #expect(host.sets[0].name == "Work" && host.sets[0].on && host.sets[0].until == FocusFiles.helperDate(until))
    }

    @Test func getFocusMayAnswerInAnotherCase() throws {
        let host = FakeFocus()
        host.effect = { fake, _, _ in fake.active = "work" }
        let after = try Focus.apply(try Focus.plan(name: "Work", on: true, until: nil, host: host), host: host, interval: 0)
        #expect(after.active == "work")
    }

    @Test func anUnchangedPlanRunsNothing() throws {
        let host = FakeFocus(active: "Work")
        _ = try Focus.apply(try Focus.plan(name: "Work", on: true, until: nil, host: host), host: host)
        #expect(host.sets.isEmpty)
    }

    @Test func aChangeThatDoesNotShowIsNotConfirmed() throws {
        let host = FakeFocus()
        host.effect = { _, _, _ in }     // the run "succeeds", nothing changes
        let plan = try Focus.plan(name: "Work", on: true, until: nil, host: host)
        #expect(throws: SettingsError.notConfirmed(id: "focus", expected: "Work", found: "no Focus", changed: false, reason: nil)) {
            try Focus.apply(plan, host: host, attempts: 3, interval: 0)
        }
        host.effect = { fake, _, _ in fake.active = "Do Not Disturb" }   // something moved, not what was asked
        #expect(throws: SettingsError.notConfirmed(id: "focus", expected: "Work", found: "Do Not Disturb", changed: true, reason: nil)) {
            try Focus.apply(plan, host: host, attempts: 3, interval: 0)
        }
    }

    @Test func aHelperThatIsNotReadyIsAHelperErrorAndAFailedRunIsNotWaitedOut() throws {
        let host = FakeFocus()
        let plan = try Focus.plan(name: "Work", on: true, until: nil, host: host)
        host.setError = HelperError.notReady(HelperStatus(id: "settings.focus-set", name: "settings · Set Focus", tool: "settings", state: .missing))
        #expect(throws: SettingsError.self) { try Focus.apply(plan, host: host, attempts: 3, interval: 0) }
        do { _ = try Focus.apply(plan, host: host, attempts: 3, interval: 0) } catch let error as SettingsError {
            guard case .helper(_, _, let remedy) = error else { Issue.record("\(error)"); return }
            #expect(remedy == "settings doctor --install, then click Add Shortcut")
        }
        host.setError = ShortcutsError.runFailed("no such Focus")
        var reads = 0
        host.effect = nil
        final class Counter: FocusHost, @unchecked Sendable {
            let inner: FakeFocus; var reads = 0
            init(_ inner: FakeFocus) { self.inner = inner }
            func modesData() -> Data? { inner.modesData() }
            func assertionsData() -> Data? { inner.assertionsData() }
            func activeFocus() throws -> String? { reads += 1; return try inner.activeFocus() }
            func setFocus(name: String, on: Bool, until: String?) throws { try inner.setFocus(name: name, on: on, until: until) }
        }
        let counter = Counter(host)
        do { _ = try Focus.apply(plan, host: counter, attempts: 20, interval: 0) } catch let error as SettingsError {
            guard case .notConfirmed(_, _, _, let changed, let reason) = error else { Issue.record("\(error)"); return }
            #expect(!changed)
            #expect(reason?.contains("no such Focus") == true)
        }
        reads = counter.reads
        #expect(reads == 3)
    }
}
