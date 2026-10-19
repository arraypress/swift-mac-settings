//
//  Setting.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One catalogued preference: what it is called, where it lives, what it may
/// be, what must restart for it to take effect, and where it was verified.
public struct Setting: Equatable, Hashable, Sendable {
    /// `group.name`, e.g. `dock.autohide`; the group part is the group's slug.
    public let id: String
    public let label: String
    public let group: String
    public let domain: String
    public let key: String
    public let host: HostScope
    public let type: SettingType
    /// How a boolean is stored when it is not a boolean: `.int` for 0/1.
    public let storage: SettingType?
    /// The allowed values, when there is a fixed set.
    public let choices: [Choice]
    public let min: Double?
    public let max: Double?
    /// What the key means when it is not set; `nil` when that is not known.
    public let defaultValue: SettingValue?
    public let restart: [Restart]
    /// The System Settings pane, as its extension id.
    public let pane: String?
    /// Where else a person changes it (a Finder menu, the screenshot toolbar).
    public let location: String?
    public let note: String?
    /// Other keys System Settings writes with it, to the same value.
    public let mirrors: [Place]
    public let writable: Bool
    public let readOnlyReason: String?
    /// macOS major versions it was probed on.
    public let verified: [String]
    /// Changed through a helper shortcut rather than cfprefsd, when set.
    public let control: Control?

    public init(id: String, label: String, group: String, domain: String, key: String, host: HostScope = .any,
                type: SettingType, storage: SettingType? = nil, choices: [Choice] = [], min: Double? = nil,
                max: Double? = nil, defaultValue: SettingValue? = nil, restart: [Restart] = [], pane: String? = nil,
                location: String? = nil, note: String? = nil, mirrors: [Place] = [], writable: Bool = true,
                readOnlyReason: String? = nil, verified: [String], control: Control? = nil) {
        self.id = id
        self.label = label
        self.group = group
        self.domain = domain
        self.key = key
        self.host = host
        self.type = type
        self.storage = storage
        self.choices = choices
        self.min = min
        self.max = max
        self.defaultValue = defaultValue
        self.restart = restart
        self.pane = pane
        self.location = location
        self.note = note
        self.mirrors = mirrors
        self.writable = writable
        self.readOnlyReason = readOnlyReason
        self.verified = verified
        self.control = control
    }
}
