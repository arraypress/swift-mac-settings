//
//  MiscTests.swift
//  MacSettingsTests
//
//  Created by David Sherlock on 2026.
//

import Foundation
import Testing
@testable import MacSettings

struct MiscTests {

    @Test func loginItemsParseFromTabbedLines() {
        let items = LoginItems.parse("Dropbox\t/Applications/Dropbox.app\tfalse\nHelper\t/Applications/Helper.app\ttrue\nbroken line\n")
        #expect(items == [LoginItem(name: "Dropbox", path: "/Applications/Dropbox.app", hidden: false),
                          LoginItem(name: "Helper", path: "/Applications/Helper.app", hidden: true)])
        #expect(LoginItems.parse("").isEmpty)
    }

    @Test func restartsAreOrderedOnceAndOnlyProcessesAreKilled() throws {
        let f = try Fixture()
        let items = [PlanItem(id: "a.b", label: "", status: .change, from: "", to: "", restart: [.logout, .dock]),
                     PlanItem(id: "a.c", label: "", status: .change, from: "", to: "", restart: [.dock, .finder])]
        #expect(Restarter.needed(items) == [.dock, .finder, .logout])
        let log = f.folder.appendingPathComponent("killed")
        let fake = f.folder.appendingPathComponent("killall")
        try "#!/bin/sh\necho \"$@\" >> '\(log.path)'\n".write(to: fake, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fake.path)
        let done = Restarter.restart([.dock, .finder, .logout, .apps], killall: fake)
        #expect(done.map(\.restart) == [.dock, .finder])
        #expect(done.allSatisfy { $0.ok })
        #expect(try String(contentsOf: log, encoding: .utf8) == "Dock\nFinder\n")
    }

    @Test func journalSelectionFindsTheLastOpenBatch() throws {
        let at = Date()
        var entries = [JournalEntry(id: "1", batch: "a", setting: "x.y", at: at),
                       JournalEntry(id: "2", batch: "b", setting: "x.y", at: at),
                       JournalEntry(id: "3", batch: "b", setting: "x.z", at: at)]
        #expect(try JournalStore.select(entries, target: nil).map(\.id) == ["2", "3"])
        entries[1].restoredAt = at
        entries[2].restoredAt = at
        #expect(try JournalStore.select(entries, target: nil).map(\.id) == ["1"])
        #expect(throws: SettingsError.self) { try JournalStore.select(entries, target: "b") }
        #expect(try JournalStore.select(entries, target: "1").map(\.id) == ["1"])
    }
}
