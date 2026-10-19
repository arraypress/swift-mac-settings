//
//  ValuesTests.swift
//  MacSettingsTests
//
//  Created by David Sherlock on 2026.
//

import Foundation
import Testing
@testable import MacSettings

struct ValuesTests {

    let f = try! Fixture()

    @Test func booleansTakePlainWords() throws {
        let s = f.setting("b")
        for word in ["on", "YES", "true", "1", "enabled"] { #expect(try s.parse(word) == .bool(true), "\(word)") }
        for word in ["off", "No", "false", "0"] { #expect(try s.parse(word) == .bool(false), "\(word)") }
        #expect(throws: SettingsError.self) { try s.parse("maybe") }
    }

    @Test func choicesMatchByLabelOrValue() throws {
        let s = f.setting("view", type: .string, choices: [Choice(value: .string("icnv"), label: "icons"),
                                                              Choice(value: .string("Nlsv"), label: "list")],
                          defaultValue: .string("icnv"))
        #expect(try s.parse("List") == .string("Nlsv"))
        #expect(try s.parse("nlsv") == .string("Nlsv"))
        #expect(throws: SettingsError.self) { try s.parse("gallery") }
        #expect(s.display(.string("Nlsv")) == "list")
    }

    @Test func numbersAreCheckedAgainstTheirRange() throws {
        let s = f.setting("delay", type: .float, min: 0, max: 5, defaultValue: .double(0.5))
        #expect(try s.parse("0.25") == .double(0.25))
        #expect(try s.parse("2") == .double(2))
        #expect(throws: SettingsError.self) { try s.parse("6") }
        #expect(throws: SettingsError.self) { try s.parse("-1") }
        #expect(throws: SettingsError.self) { try s.parse("nan") }
        let i = f.setting("size", type: .int, min: 1, max: 3, defaultValue: .int(2))
        #expect(throws: SettingsError.self) { try i.parse("2.5") }
        #expect(try i.parse("3") == .int(3))
    }

    @Test func defaultMeansRemoveTheKey() throws {
        #expect(try f.setting("x").parse("default") == nil)
    }

    @Test func storedFormsFollowTheCatalogue() {
        #expect(Values.stored(.bool(true), for: f.setting("a")) == .bool(true))
        #expect(Values.stored(.bool(true), for: f.setting("b", storage: .int)) == .int(1))
        #expect(Values.stored(.int(48), for: f.setting("c", type: .float, defaultValue: nil)) == .real(48))
        #expect(Values.stored(.int(2), for: f.setting("d", type: .int, defaultValue: nil)) == .int(2))
    }

    @Test func storedValuesReadAsTheSettingsType() {
        let b = f.setting("b")
        #expect(Values.logical(.int(1), for: b) == .bool(true))
        #expect(Values.logical(.int(0), for: b) == .bool(false))
        #expect(Values.logical(.string("YES"), for: b) == .bool(true))
        #expect(Values.logical(.string("banana"), for: b) == nil)
        #expect(Values.logical(.absent, for: b) == nil)
        let i = f.setting("i", type: .int, defaultValue: nil)
        #expect(Values.logical(.real(14), for: i) == .int(14))
        #expect(Values.logical(.real(1.5), for: i) == nil)
        let r = f.setting("r", type: .float, defaultValue: nil)
        #expect(Values.logical(.int(3), for: r) == .double(3))
    }

    @Test func sameComparesValuesNotEncodings() {
        #expect(Values.same(.double(0.2), .double(0.2 + 1e-12)))
        #expect(Values.same(.int(48), .double(48)))
        #expect(!Values.same(.double(0.2), .double(0.25)))
        #expect(!Values.same(.bool(true), .int(1)))
        #expect(!Values.same(nil, .bool(false)))
    }

    @Test func displayIsPlain() {
        let b = f.setting("b")
        #expect(b.display(.bool(true)) == "on")
        #expect(b.display(nil) == "not set")
        #expect(Values.text(.double(48)) == "48")
        #expect(Values.text(.double(0.5)) == "0.5")
    }

    @Test func settingValueJSONIsTheBareValue() throws {
        let values: [SettingValue] = [.bool(true), .int(48), .double(0.5), .string("bottom")]
        let data = try JSONEncoder().encode(values)
        #expect(String(decoding: data, as: UTF8.self) == #"[true,48,0.5,"bottom"]"#)
        #expect(try JSONDecoder().decode([SettingValue].self, from: data) == values)
    }

    @Test func storedValueJSONKeepsTheType() throws {
        let values: [StoredValue] = [.absent, .bool(false), .int(1), .real(1), .string("x"), .plist(Data([1, 2]))]
        let back = try JSONDecoder().decode([StoredValue].self, from: JSONEncoder().encode(values))
        #expect(back == values)
        #expect(throws: (any Error).self) { try JSONDecoder().decode(StoredValue.self, from: Data(#"{"int":1,"bool":true}"#.utf8)) }
    }

    @Test func suggestionsFindTheNearID() {
        let ids = ["dock.autohide", "dock.autohide-delay", "finder.path-bar"]
        #expect(Suggest.closest("dock.autohid", among: ids).first == "dock.autohide")
        #expect(Suggest.closest("pathbar", among: ids).isEmpty || Suggest.closest("path-bar", among: ids) == ["finder.path-bar"])
        #expect(Groups.matches("menubar", group: "Menu bar"))
        #expect(Groups.matches("MENU-BAR", group: "Menu bar"))
        #expect(!Groups.matches("menu", group: "Menu bar"))
    }
}
