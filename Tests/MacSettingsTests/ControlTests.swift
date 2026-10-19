//
//  ControlTests.swift
//  MacSettingsTests
//
//  Created by David Sherlock on 2026.
//
//  Settings only a helper shortcut can change, against fake readers and a
//  fake helper: nothing here touches Low Power, Bluetooth or the display.
//

import AppleShortcuts
import Foundation
import Testing
@testable import MacSettings

/// Readers that answer from a table, and a helper that changes the table — or not.
final class FakeControls: SystemControls, @unchecked Sendable {
    var values: [String: ProbeReading] = [:]
    var runs: [(helper: String, input: [String: PlistValue])] = []
    var effect: ((FakeControls, String, [String: PlistValue]) -> Void)?
    var error: Error?

    func read(probe: String) -> ProbeReading { values[probe] ?? .unavailable("no fake value") }
    func run(helper: String, input: [String: PlistValue]) throws {
        runs.append((helper, input))
        if let error { throw error }
        effect?(self, helper, input)
    }
}

struct ControlTests {

    func liveSetting(_ probe: String = "low-power", type: SettingType = .bool, defaultValue: SettingValue? = .bool(false),
                     field: String = "on", writable: Bool = true) -> Setting {
        Setting(id: "system.\(probe)", label: probe, group: "System", domain: "(macOS)", key: probe, type: type,
                min: type == .float ? 0 : nil, max: type == .float ? 1 : nil, defaultValue: defaultValue,
                verified: ["27"], control: field == "on"
                    ? Control(helper: "settings.system", keys: ["on": "\(probe)-on", "off": "\(probe)-off"], probe: probe)
                    : Control(helper: "settings.system", field: field, probe: probe))
    }

    func context(_ f: Fixture, _ controls: FakeControls) -> SettingsContext {
        var context = f.context()
        context.controls = controls
        context.controlInterval = 0
        context.controlAttempts = 4
        return context
    }

    /// A helper that sets the probe to what it was asked.
    func obedient(_ controls: FakeControls) {
        controls.effect = { fake, _, input in
            for (key, value) in input {
                if key.hasSuffix("-on") { fake.values[String(key.dropLast(3))] = .value(.bool(true)) }
                if key.hasSuffix("-off") { fake.values[String(key.dropLast(4))] = .value(.bool(false)) }
                if case .double(let level) = value { fake.values[key] = .value(.double(level)) }
            }
        }
    }

    @Test func aReaderSettingReadsFromItsProbe() throws {
        let f = try Fixture()
        let controls = FakeControls()
        controls.values["low-power"] = .value(.bool(true))
        let reading = Reader.read(liveSetting(), context: context(f, controls))
        #expect(reading.value == .bool(true) && reading.display == "on" && reading.changed && reading.set)
        controls.values["low-power"] = .value(.bool(false))
        #expect(!Reader.read(liveSetting(), context: context(f, controls)).changed)
        #expect(Reader.read(liveSetting(defaultValue: nil), context: context(f, controls)).changed)
        controls.values["low-power"] = .unavailable("not on this Mac")
        let gone = Reader.read(liveSetting(), context: context(f, controls))
        #expect(gone.value == nil && gone.display == "unavailable: not on this Mac" && gone.unreadable == "not on this Mac")
    }

    @Test func plans() throws {
        let f = try Fixture()
        let controls = FakeControls()
        controls.values["low-power"] = .value(.bool(false))
        let ctx = context(f, controls)
        let setting = liveSetting()
        let change = Planner.plan(setting, to: .bool(true), context: ctx)
        #expect(change.status == .change && change.control?.before == .bool(false) && change.control?.after == .bool(true))
        #expect(change.writes.isEmpty)
        #expect(Planner.plan(setting, to: .bool(false), context: ctx).status == .unchanged)
        // "default" is the default value, set through the helper.
        controls.values["low-power"] = .value(.bool(true))
        #expect(Planner.plan(setting, to: nil, context: ctx).control?.after == .bool(false))
        #expect(Planner.plan(liveSetting(defaultValue: nil), to: nil, context: ctx).skip == .invalidValue)
        // Not readable here: not written.
        controls.values["low-power"] = .unavailable("no")
        let refused = Planner.plan(setting, to: .bool(true), context: ctx)
        #expect(refused.status == .skipped && refused.skip == .notWritable && refused.reason?.contains("cannot be read back") == true)
        #expect(controls.runs.isEmpty)
    }

    @Test func inputIsOneKeyPerValueOrTheNumberItself() {
        let appearance = Control(helper: "settings.system", keys: ["Light": "appearance-light", "Dark": "appearance-dark"])
        #expect(ControlInput.input(appearance, value: .string("Dark")) == ["appearance-dark": .bool(true)])
        #expect(ControlInput.input(appearance, value: .string("Other")) == nil)
        let night = Control(helper: "settings.system", keys: ["on": "night-shift-on", "off": "night-shift-off"])
        #expect(ControlInput.input(night, value: .bool(false)) == ["night-shift-off": .bool(true)])
        let level = Control(helper: "settings.system", field: "brightness")
        #expect(ControlInput.input(level, value: .int(1)) == ["brightness": .double(1)])
        #expect(ControlInput.input(level, value: .double(0.4)) == ["brightness": .double(0.4)])
        #expect(ControlInput.input(Control(helper: "x"), value: .bool(true)) == nil)
    }

    @Test func applyJournalsRunsAndBelievesOnlyTheReadBackThenUndoPutsItBack() throws {
        let f = try Fixture()
        let controls = FakeControls()
        controls.values["low-power"] = .value(.bool(false))
        obedient(controls)
        let ctx = context(f, controls)
        let setting = liveSetting()
        let catalogue = f.catalogue([setting])
        let item = Planner.plan(setting, to: .bool(true), context: ctx)
        let outcomes = try Applier.apply([item], context: ctx, catalogue: catalogue)
        #expect(outcomes.map(\.result) == [.applied])
        #expect(controls.runs.map(\.helper) == ["settings.system"])
        #expect(controls.runs.first?.input == ["low-power-on": .bool(true)])
        let journal = try JournalStore.load(ctx.journal)
        #expect(journal.count == 1 && journal[0].valueBefore == .bool(false) && journal[0].valueAfter == .bool(true))

        let undone = try Undoer.undo(nil, context: ctx, catalogue: catalogue)
        #expect(undone.map(\.result) == [.restored])
        #expect(controls.values["low-power"] == .value(.bool(false)))
        #expect(controls.runs.last?.input == ["low-power-off": .bool(true)])
    }

    @Test func aWriteThatDoesNotShowFailsWithItsReason() throws {
        let f = try Fixture()
        let controls = FakeControls()
        controls.values["low-power"] = .value(.bool(false))
        let ctx = context(f, controls)
        let setting = liveSetting()
        let outcome = try Applier.apply([Planner.plan(setting, to: .bool(true), context: ctx)], context: ctx, catalogue: f.catalogue([setting]))
        #expect(outcome.first?.result == .failed)
        #expect(outcome.first?.reason == "reads back as off, not on")
    }

    @Test func aHelperThatIsNotReadyFailsAtOnceAndSaysHowToFixIt() throws {
        let f = try Fixture()
        let controls = FakeControls()
        controls.values["low-power"] = .value(.bool(false))
        controls.error = HelperError.notReady(HelperStatus(id: "settings.system", name: "settings · Set System Setting", tool: "settings",
                                                           state: .missing, install: "settings doctor --install"))
        let ctx = context(f, controls)
        let setting = liveSetting()
        let outcome = try Applier.apply([Planner.plan(setting, to: .bool(true), context: ctx)], context: ctx, catalogue: f.catalogue([setting]))
        #expect(outcome.first?.result == .failed)
        #expect(outcome.first?.reason?.contains("settings doctor --install") == true)
    }

    @Test func undoLeavesAValueChangedSinceAlone() throws {
        let f = try Fixture()
        let controls = FakeControls()
        controls.values["brightness"] = .value(.double(0.3))
        obedient(controls)
        let ctx = context(f, controls)
        let setting = liveSetting("brightness", type: .float, defaultValue: nil, field: "brightness")
        let catalogue = f.catalogue([setting])
        _ = try Applier.apply([Planner.plan(setting, to: .double(0.8), context: ctx)], context: ctx, catalogue: catalogue)
        controls.values["brightness"] = .value(.double(0.5))     // someone moved it
        let conflict = try Undoer.undo(nil, context: ctx, catalogue: catalogue)
        #expect(conflict.map(\.result) == [.conflict])
        #expect(controls.runs.count == 1)
        let forced = try Undoer.undo(nil, context: ctx, force: true, catalogue: catalogue)
        #expect(forced.map(\.result) == [.restored] && controls.values["brightness"] == .value(.double(0.3)))
    }

    @Test func aPreferenceBackedControlIsReadFromItsKey() throws {
        let f = try Fixture()
        let place = f.place("appearance")
        let setting = Setting(id: "tests.appearance", label: "Appearance", group: "Tests", domain: place.domain, key: place.key,
                              type: .string, choices: [Choice(value: .string("Light"), label: "light"), Choice(value: .string("Dark"), label: "dark")],
                              defaultValue: .string("Light"), verified: ["27"],
                              control: Control(helper: "settings.system", keys: ["Light": "appearance-light", "Dark": "appearance-dark"]))
        let controls = FakeControls()
        let store = f.store
        controls.effect = { _, _, input in
            if input["appearance-dark"] != nil { store.write(.string("Dark"), to: place) }
            if input["appearance-light"] != nil { store.write(.absent, to: place) }
        }
        let ctx = context(f, controls)
        let item = Planner.plan(setting, to: .string("Dark"), context: ctx)
        #expect(item.status == .change && item.control?.before == .string("Light"))
        let outcome = try Applier.apply([item], context: ctx, catalogue: f.catalogue([setting]))
        #expect(outcome.map(\.result) == [.applied])
        #expect(controls.runs.first?.input == ["appearance-dark": .bool(true)])
        #expect(f.store.read(place) == .string("Dark"))
    }

    @Test func catalogueRulesForControls() throws {
        func problems(_ setting: Setting) -> [String] { CatalogueCheck.controlProblems(setting, label: setting.id) }
        func live(_ control: Control, writable: Bool = true, domain: String = "(macOS)", key: String = "night-shift") -> Setting {
            Setting(id: "system.night-shift", label: "n", group: "System", domain: domain, key: key, type: .bool,
                    writable: writable, readOnlyReason: writable ? nil : "r", verified: ["27"], control: control)
        }
        let good = Control(helper: "settings.system", keys: ["on": "night-shift-on", "off": "night-shift-off"], probe: "night-shift")
        #expect(problems(live(good)).isEmpty)
        #expect(problems(Setting(id: "x.y", label: "y", group: "X", domain: "(macOS)", key: "y", type: .bool, verified: ["27"])).first?.contains("is for settings with a reader") == true)
        #expect(problems(live(Control(helper: "settings.nope", keys: good.keys, probe: "night-shift"))).contains("system.night-shift: no helper settings.nope"))
        #expect(problems(live(Control(helper: "settings.system", keys: ["on": "night-shift-on", "off": "nope"], probe: "night-shift"))).contains("system.night-shift: settings.system takes no nope"))
        #expect(problems(live(Control(helper: "settings.system", keys: ["yes": "night-shift-on", "no": "night-shift-off"], probe: "night-shift"))).contains("system.night-shift: a switch's keys are on and off"))
        #expect(problems(live(Control(helper: "settings.system", probe: "night-shift"))).contains("system.night-shift: a control has keys or a field, not both or neither"))
        #expect(problems(live(Control(helper: "settings.system", keys: good.keys, probe: "wifi"), key: "wifi")).contains("system.night-shift: no reader wifi"))
        #expect(problems(live(good, key: "k")).contains("system.night-shift: a setting with a reader is (macOS) / night-shift"))
        #expect(problems(live(Control(helper: nil, probe: "night-shift"))).contains("system.night-shift: a setting with no helper is read-only"))
        #expect(problems(live(Control(helper: nil, probe: "night-shift"), writable: false)).isEmpty)
        #expect(problems(live(good, writable: false)).contains("system.night-shift: a setting with a helper is writable"))
        let noReader = Setting(id: "x.y", label: "y", group: "X", domain: "(macOS)", key: "k", type: .bool, verified: ["27"],
                               control: Control(helper: "settings.system", keys: good.keys))
        #expect(problems(noReader).contains("x.y: (macOS) needs a reader"))
    }

    @Test func theBuiltInSystemSettingsAreAllWritableThroughHelpers() throws {
        let catalogue = try Catalogue.builtIn()
        let controlled = catalogue.settings.filter { $0.control != nil }.map(\.id).sorted()
        #expect(controlled == ["appearance.mode", "system.airdrop", "system.bluetooth", "system.brightness",
                               "system.low-power", "system.night-shift", "system.true-tone"])
        let writable = catalogue.settings.filter { $0.control?.helper != nil }.allSatisfy { $0.writable }
        #expect(writable)
        #expect(catalogue.setting("system.low-power")?.writable == false)
        #expect(catalogue.setting("desktop.stage-manager")?.writable == false)
        #expect(catalogue.setting("appearance.auto-switch")?.writable == false)
    }
}
