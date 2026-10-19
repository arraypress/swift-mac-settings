//
//  FocusFiles.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//
//  The Do Not Disturb store's own files, read for the list of Focus modes and
//  as a second opinion on which is on. Pure: the parsers take bytes.
//
//  MEASURED on macOS 27.0.1: `~/Library/DoNotDisturb/DB/ModeConfigurations.json`
//  is `{"data": [{"modeConfigurations": {<id>: {"mode": {"name", "modeIdentifier"}}}}]}`;
//  `Assertions.json` keeps the Focus that is on under `storeAssertionRecords`,
//  each with `assertionDetails.assertionDetailsModeIdentifier` and a lifetime
//  (`assertionDetailsLifetimeType`: `schedule` for "until the schedule ends").
//  Neither file is documented: Get Focus, a Shortcuts action, is the reading
//  that counts, and these only fill in what it cannot say.
//

import Foundation

enum FocusFiles {

    static var folder: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/DoNotDisturb/DB")
    }

    /// Every Focus mode, by name.
    static func modes(_ data: Data) -> [FocusMode] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let records = root["data"] as? [[String: Any]] else { return [] }
        var found: [FocusMode] = []
        for record in records {
            let configurations = record["modeConfigurations"] as? [String: Any] ?? [:]
            for (key, value) in configurations {
                guard let mode = (value as? [String: Any])?["mode"] as? [String: Any],
                      let name = mode["name"] as? String else { continue }
                found.append(FocusMode(id: mode["modeIdentifier"] as? String ?? key, name: name))
            }
        }
        return Array(Set(found)).sorted { $0.name < $1.name }
    }

    /// The asserted Focus's id and lifetime type, the newest when there are several.
    static func assertion(_ data: Data) -> (mode: String, lifetime: String?)? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let records = root["data"] as? [[String: Any]] else { return nil }
        let assertions = records.flatMap { $0["storeAssertionRecords"] as? [[String: Any]] ?? [] }
        let newest = assertions.max {
            ($0["assertionStartDateTimestamp"] as? Double ?? 0) < ($1["assertionStartDateTimestamp"] as? Double ?? 0)
        }
        guard let details = newest?["assertionDetails"] as? [String: Any],
              let mode = details["assertionDetailsModeIdentifier"] as? String else { return nil }
        let lifetime = (details["assertionDetailsLifetime"] as? [String: Any])?["assertionDetailsLifetimeType"] as? String
        return (mode, lifetime)
    }

    /// The mode a typed name means: exact, then ignoring case and accents.
    static func mode(named typed: String, in modes: [FocusMode]) -> FocusMode? {
        let wanted = typed.trimmingCharacters(in: .whitespaces)
        return modes.first { $0.name == wanted }
            ?? modes.first { $0.name.compare(wanted, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
            ?? modes.first { $0.id == wanted }
    }

    /// `until` as the helper takes it: local `yyyy-MM-dd HH:mm`.
    static func helperDate(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}
