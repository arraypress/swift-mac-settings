//
//  SettingsError.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Why something in this library refused or failed.
public enum SettingsError: Error, Equatable, Sendable {
    /// The catalogue JSON is malformed or breaks a rule of its own.
    case invalidCatalogue(String)
    /// No setting by that id; the closest ids, if any.
    case unknownSetting(String, suggestions: [String])
    /// No group by that name; the groups there are.
    case unknownGroup(String, groups: [String])
    /// A value that does not fit the setting, and why.
    case invalidValue(id: String, reason: String)
    /// The catalogue marks it read-only; where to change it instead.
    case notWritable(id: String, reason: String, paneURL: String?)
    /// A configuration profile sets it.
    case locked(id: String, paneURL: String?)
    /// Not probed on this macOS; `--unverified` allows it.
    case unverified(id: String, macOS: String)
    /// No installed app by that name or bundle id can open it.
    case appNotFound(String, forID: String)
    /// A snapshot file that cannot be read, and why.
    case invalidSnapshot(String)
    /// No journal entry or batch by that id.
    case journalEntryNotFound(String)
    /// The journal could not be read or written.
    case journal(String)
}

extension SettingsError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidCatalogue(let reason): "the settings catalogue is invalid: \(reason)"
        case .unknownSetting(let id, let suggestions):
            "no setting called \(id)" + (suggestions.isEmpty ? "" : " — did you mean \(suggestions.joined(separator: ", "))?")
        case .unknownGroup(let name, _): "no group called \(name)"
        case .invalidValue(let id, let reason): "\(id): \(reason)"
        case .notWritable(let id, let reason, _): "\(id) is read-only here: \(reason)"
        case .locked(let id, _): "\(id) is set by a configuration profile (MDM or Screen Time) and cannot be changed here"
        case .unverified(let id, let macOS): "\(id) has not been verified on macOS \(macOS)"
        case .appNotFound(let app, let id): "no installed app called \(app) can be the default for \(id)"
        case .invalidSnapshot(let reason): "not a settings snapshot: \(reason)"
        case .journalEntryNotFound(let id): "nothing in the undo journal is called \(id)"
        case .journal(let reason): "the undo journal: \(reason)"
        }
    }
}
