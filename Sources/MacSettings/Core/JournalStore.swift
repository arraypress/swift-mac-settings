//
//  JournalStore.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//
//
//  The undo journal: one JSON file of every write, saved BEFORE the write it
//  records. A crash between the two leaves an entry whose "before" is still
//  the value in place, so undoing it is harmless; the other order could leave
//  a change nobody can undo.
//

import Foundation

public enum JournalStore {

    /// Every entry, oldest first. A missing journal is empty; an unreadable
    /// one is an error, never quietly empty.
    public static func load(_ url: URL) throws(SettingsError) -> [JournalEntry] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([JournalEntry].self, from: Data(contentsOf: url))
        } catch {
            throw .journal("cannot read \(url.path): \(error.localizedDescription)")
        }
    }

    public static func save(_ entries: [JournalEntry], to url: URL) throws(SettingsError) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(entries).write(to: url, options: .atomic)
        } catch {
            throw .journal("cannot write \(url.path): \(error.localizedDescription)")
        }
    }

    static func append(_ new: [JournalEntry], to url: URL) throws(SettingsError) {
        try save(try load(url) + new, to: url)
    }

    /// The entries an undo target names: `nil` is the last batch not yet
    /// undone, otherwise a batch id or a single entry id.
    public static func select(_ entries: [JournalEntry], target: String?) throws(SettingsError) -> [JournalEntry] {
        guard let target else {
            guard let batch = entries.last(where: { $0.restoredAt == nil })?.batch else {
                throw .journalEntryNotFound("the last batch")
            }
            return entries.filter { $0.batch == batch && $0.restoredAt == nil }
        }
        let chosen = entries.filter { ($0.batch == target || $0.id == target) && $0.restoredAt == nil }
        guard !chosen.isEmpty else { throw .journalEntryNotFound(target) }
        return chosen
    }

    /// A new batch id: sortable, and unique enough for one person's Mac.
    public static func newBatch(at date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date) + "-" + String(UUID().uuidString.prefix(4)).lowercased()
    }
}
