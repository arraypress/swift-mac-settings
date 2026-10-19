//
//  LearnTests.swift
//  MacSettingsTests
//
//  Created by David Sherlock on 2026.
//

import Foundation
import Testing
@testable import MacSettings

struct LearnTests {

    @Test func fileNamesBecomeDomains() {
        #expect(PreferenceScanner.domain(fromFile: "com.apple.dock.plist", byHost: false) == "com.apple.dock")
        #expect(PreferenceScanner.domain(fromFile: ".GlobalPreferences.plist", byHost: false) == "NSGlobalDomain")
        #expect(PreferenceScanner.domain(fromFile: "com.apple.screensaver.00000000-0000-4000-8000-000000000001.plist", byHost: true)
                == "com.apple.screensaver")
        #expect(PreferenceScanner.domain(fromFile: ".GlobalPreferences.00000000-0000-4000-8000-000000000001.plist", byHost: true)
                == "NSGlobalDomain")
        #expect(PreferenceScanner.domain(fromFile: "com.apple.x.plist.lockfile", byHost: false) == nil)
        #expect(PreferenceScanner.domain(fromFile: "com.apple.nohost.plist", byHost: true) == nil)
    }

    @Test func aScanSeesAnotherProcesssWrite() throws {
        let f = try Fixture()
        let place = f.place("learn")
        let domains: [(domain: String, host: HostScope)] = [(scratchDomain, .any)]
        let before = PreferenceScanner.scan(domains)
        f.defaultsWrite(place, ["-bool", "true"])
        let after = PreferenceScanner.scan(domains)
        let changes = PreferenceScanner.changes(from: before, to: after).filter { $0.place == place }
        #expect(changes.count == 1)
        #expect(changes.first?.from == .absent && changes.first?.to == .bool(true))
    }

    @Test func noiseFromTheBaselineIsLeftOut() throws {
        let f = try Fixture()
        let s = f.setting("watched")
        let noisy = Place(domain: "com.example.noisy", key: "heartbeat")
        var tracker = ChangeTracker()
        tracker.baseline(noisy)
        tracker.record(noisy, from: .int(1), to: .int(2))
        tracker.record(s.place, from: .absent, to: .bool(true))
        tracker.record(s.place, from: .bool(true), to: .bool(false))
        let changes = tracker.changes(catalogue: f.catalogue([s]))
        #expect(changes.count == 1)
        #expect(changes.first?.times == 2)
        #expect(changes.first?.from == .absent && changes.first?.to == .bool(false))
        #expect(changes.first?.setting == s.id)
    }
}
