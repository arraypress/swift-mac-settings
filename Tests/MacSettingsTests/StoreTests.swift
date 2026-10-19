//
//  StoreTests.swift
//  MacSettingsTests
//
//  Created by David Sherlock on 2026.
//
//
//  The live store against the real cfprefsd, on the scratch domain only.
//

import Foundation
import Testing
@testable import MacSettings

struct StoreTests {

    @Test func everyKindRoundTripsExactly() throws {
        let f = try Fixture()
        let array = PlistValues.stored(["a", "b"] as CFArray)
        for (index, value) in [StoredValue.bool(true), .int(1), .real(0.25), .string("hello"), array].enumerated() {
            let place = f.place("kind\(index)")
            #expect(f.store.write(value, to: place))
            #expect(f.store.read(place) == value, "\(value)")
        }
    }

    @Test func anIntegerOneStaysAnIntegerAndTrueStaysABoolean() throws {
        let f = try Fixture()
        let a = f.place("int"), b = f.place("bool")
        f.store.write(.int(1), to: a)
        f.store.write(.bool(true), to: b)
        #expect(f.store.read(a) == .int(1))
        #expect(f.store.read(b) == .bool(true))
        #expect(f.defaultsRead(a) == "1")
    }

    @Test func absentRemovesTheKey() throws {
        let f = try Fixture()
        let place = f.place("gone")
        f.store.write(.string("x"), to: place)
        f.store.write(.absent, to: place)
        #expect(f.store.read(place) == .absent)
        #expect(f.defaultsRead(place) == nil)
    }

    @Test func anotherProcessSeesTheWriteAndViceVersa() throws {
        let f = try Fixture()
        let place = f.place("shared")
        f.store.write(.int(42), to: place)
        #expect(f.defaultsRead(place) == "42")
        f.defaultsWrite(place, ["-float", "1.5"])
        #expect(f.store.read(place) == .real(1.5))
    }

    @Test func theCurrentHostCopyIsSeparate() throws {
        let f = try Fixture()
        let any = f.place("host"), here = Place(domain: any.domain, key: any.key, host: .current)
        _ = f.place("host", host: .current)
        f.store.write(.int(1), to: any)
        f.store.write(.int(2), to: here)
        #expect(f.store.read(any) == .int(1))
        #expect(f.store.read(here) == .int(2))
        #expect(f.defaultsRead(here) == "2")
        f.store.write(.absent, to: here)
    }

    @Test func managedProfilesLockTheirKeys() throws {
        let f = try Fixture()
        let managed = ManagedPreferences(root: f.managedRoot, user: "tester")
        try f.manage("com.example.locked", keys: ["Mine": true])
        try f.manage("com.example.computer", keys: ["Theirs": 1], forUser: false)
        try f.manage("NSGlobalDomain", keys: ["AppleShowScrollBars": "Always"])
        #expect(managed.isManaged(Place(domain: "com.example.locked", key: "Mine")))
        #expect(!managed.isManaged(Place(domain: "com.example.locked", key: "Other")))
        #expect(managed.isManaged(Place(domain: "com.example.computer", key: "Theirs")))
        #expect(managed.isManaged(Place(domain: "NSGlobalDomain", key: "AppleShowScrollBars")))
        #expect(!ManagedPreferences(root: f.managedRoot, user: "someone-else").isManaged(Place(domain: "com.example.locked", key: "Mine")))
    }
}
