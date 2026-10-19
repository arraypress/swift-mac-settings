//
//  Snapshot.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A Mac's setup as a file: every catalogued value, with the macOS and the
/// time it was read. Also what a person writes by hand to describe a setup —
/// only `settings[].id` and `value` are required.
public struct Snapshot: Equatable, Sendable {
    /// Always ``Snapshot/kindName``, so a stray JSON file is refused.
    public let kind: String
    public let version: Int
    public let macOS: String?
    public let build: String?
    /// ISO 8601.
    public let takenAt: String?
    public let catalogue: Int?
    public let settings: [SnapshotSetting]
    public let defaultApps: [SnapshotApp]

    public static let kindName = "settings-snapshot"

    public init(kind: String = Snapshot.kindName, version: Int = 1, macOS: String? = nil, build: String? = nil,
                takenAt: String? = nil, catalogue: Int? = nil, settings: [SnapshotSetting], defaultApps: [SnapshotApp] = []) {
        self.kind = kind
        self.version = version
        self.macOS = macOS
        self.build = build
        self.takenAt = takenAt
        self.catalogue = catalogue
        self.settings = settings
        self.defaultApps = defaultApps
    }
}

/// One setting in a snapshot.
public struct SnapshotSetting: Equatable, Sendable {
    public let id: String
    public let label: String?
    public let group: String?
    /// `nil` with `set: false` means "not set": applying it removes the key.
    public let value: SettingValue?
    /// Whether the key was stored. Missing means stored when there is a value.
    public let set: Bool?
    public let locked: Bool?

    public init(id: String, label: String? = nil, group: String? = nil, value: SettingValue?, set: Bool? = nil, locked: Bool? = nil) {
        self.id = id
        self.label = label
        self.group = group
        self.value = value
        self.set = set
        self.locked = locked
    }

    /// Whether this entry asks for the key to be stored.
    public var isSet: Bool { self.set ?? (value != nil) }
}

/// One default app in a snapshot.
public struct SnapshotApp: Codable, Equatable, Sendable {
    public let id: String
    public let label: String?
    /// The bundle id.
    public let app: String?
    /// The app's name, for people.
    public let name: String?

    public init(id: String, label: String? = nil, app: String?, name: String? = nil) {
        self.id = id
        self.label = label
        self.app = app
        self.name = name
    }
}
