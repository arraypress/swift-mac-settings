//
//  ReaderTests.swift
//  MacSettingsTests
//
//  Created by David Sherlock on 2026.
//

import Foundation
import Testing
@testable import MacSettings

struct ReaderTests {

    @Test func unsetMeansTheDefault() throws {
        let f = try Fixture()
        let s = f.setting("unset", defaultValue: .bool(true))
        let reading = Reader.read(s, context: f.context())
        #expect(reading.value == .bool(true))
        #expect(!reading.set)
        #expect(!reading.changed)
        #expect(reading.display == "on")
    }

    @Test func setToTheDefaultIsNotChangedAndOtherwiseIs() throws {
        let f = try Fixture()
        let s = f.setting("same", type: .float, defaultValue: .double(0.5))
        f.store.write(.real(0.5), to: s.place)
        #expect(Reader.read(s, context: f.context()).set)
        #expect(!Reader.read(s, context: f.context()).changed)
        f.store.write(.int(1), to: s.place)
        let reading = Reader.read(s, context: f.context())
        #expect(reading.changed)
        #expect(reading.value == .double(1))
    }

    @Test func aStoredValueWithAnUnknownDefaultCountsAsChanged() throws {
        let f = try Fixture()
        let s = f.setting("nodefault", type: .int, defaultValue: nil)
        #expect(Reader.read(s, context: f.context()).value == nil)
        #expect(Reader.read(s, context: f.context()).display == "not set")
        f.store.write(.int(3), to: s.place)
        #expect(Reader.read(s, context: f.context()).changed)
    }

    @Test func booleansKeptAsIntegersReadAsBooleans() throws {
        let f = try Fixture()
        let s = f.setting("clicking", storage: .int)
        f.store.write(.int(1), to: s.place)
        #expect(Reader.read(s, context: f.context()).value == .bool(true))
    }

    @Test func aMalformedValueIsUnreadableNotGuessed() throws {
        let f = try Fixture()
        let s = f.setting("odd")
        f.store.write(.string("banana"), to: s.place)
        let reading = Reader.read(s, context: f.context())
        #expect(reading.value == nil)
        #expect(reading.unreadable?.contains("banana") == true)
    }

    @Test func aProfileLocksTheReading() throws {
        let f = try Fixture()
        let s = f.setting("locked")
        #expect(!Reader.read(s, context: f.context()).locked)
        try f.manage(scratchDomain, keys: [s.key: true])
        #expect(Reader.read(s, context: f.context()).locked)
    }

    @Test func verifiedFollowsTheMajorVersion() throws {
        let f = try Fixture()
        let s = f.setting("v")
        #expect(Reader.read(s, context: f.context(system: "27.1")).verified)
        #expect(!Reader.read(s, context: f.context(system: "15.6")).verified)
    }

    @Test func listingAGroupReadsOnlyThatGroup() throws {
        let f = try Fixture()
        let a = f.setting("a", group: "Tests"), b = f.setting("b", group: "Other")
        let catalogue = f.catalogue([a, b], apps: [browserEntry()])
        #expect(Reader.readAll(catalogue, group: "Other", context: f.context()).map(\.id) == ["other.b"])
        #expect(Reader.readAll(catalogue, context: f.context()).count == 3)
        #expect(try catalogue.group(named: "other") == "Other")
        #expect(throws: SettingsError.self) { try catalogue.group(named: "nope") }
        #expect(throws: SettingsError.self) { try Reader.read(id: "tests.nope", in: catalogue, context: f.context()) }
    }

    @Test func aDefaultAppReadsItsHandler() throws {
        let f = try Fixture()
        f.apps.preset("http", "com.example.other")
        f.apps.preset("https", "com.example.other")
        let reading = Reader.read(browserEntry(), context: f.context())
        #expect(reading.value == .string("com.example.other"))
        #expect(reading.display == "Other Browser")
        #expect(reading.changed)
        f.apps.preset("https", "com.example.browser")
        #expect(Reader.read(browserEntry(), context: f.context()).display == "Other Browser (http), Example Browser (https)")
    }
}
