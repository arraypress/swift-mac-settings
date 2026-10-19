//
//  Reading.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One setting (or default app) as it is on this Mac now.
public struct Reading: Codable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let group: String
    /// The value in force: what is stored, or the default when nothing is.
    /// `nil` when nothing is stored and the default is not known.
    public let value: SettingValue?
    /// The value in words: `on`, `list`, `0.2`, `not set`.
    public let display: String
    /// Whether the key is stored, rather than left to its default.
    public let set: Bool
    /// Stored, and different from the default (or the default is unknown).
    public let changed: Bool
    /// A configuration profile sets it.
    public let locked: Bool
    public let writable: Bool
    /// Probed on this macOS major version.
    public let verified: Bool
    /// What the stored value could not be read as, when it is malformed.
    public let unreadable: String?

    public init(id: String, label: String, group: String, value: SettingValue?, display: String, set: Bool,
                changed: Bool, locked: Bool, writable: Bool, verified: Bool, unreadable: String? = nil) {
        self.id = id
        self.label = label
        self.group = group
        self.value = value
        self.display = display
        self.set = set
        self.changed = changed
        self.locked = locked
        self.writable = writable
        self.verified = verified
        self.unreadable = unreadable
    }
}
