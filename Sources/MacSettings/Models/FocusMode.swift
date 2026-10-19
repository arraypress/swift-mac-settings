//
//  FocusMode.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A Focus this Mac has set up: Do Not Disturb, Work, Sleep…
public struct FocusMode: Codable, Equatable, Hashable, Sendable {
    /// `com.apple.donotdisturb.mode.default`, `com.apple.focus.work`.
    public let id: String
    /// What Shortcuts and Control Center call it.
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// The Focus as it is now.
public struct FocusReading: Codable, Equatable, Sendable {
    /// The Focus that is on, by name, as Shortcuts' Get Focus says; `nil` when none is.
    public let active: String?
    /// The Focus the Do Not Disturb store records as asserted, when it records one.
    public let asserted: FocusMode?
    /// How the asserted Focus ends: `schedule`, `date`, `none`… as the store says.
    public let lifetime: String?
    /// Every Focus set up on this Mac.
    public let modes: [FocusMode]

    public init(active: String?, asserted: FocusMode?, lifetime: String?, modes: [FocusMode]) {
        self.active = active
        self.asserted = asserted
        self.lifetime = lifetime
        self.modes = modes
    }
}

/// What `settings focus on|off` will do.
public struct FocusPlan: Codable, Equatable, Sendable {
    /// The Focus on now, or `nil`.
    public let from: String?
    /// The Focus that will be on after, or `nil` for none.
    public let to: String?
    /// The Focus named in the request.
    public let mode: FocusMode
    public let on: Bool
    /// When it turns itself off; `nil`: when turned off.
    public let until: Date?
    /// Nothing to do: it is already as asked.
    public let unchanged: Bool

    public init(from: String?, to: String?, mode: FocusMode, on: Bool, until: Date?, unchanged: Bool) {
        self.from = from
        self.to = to
        self.mode = mode
        self.on = on
        self.until = until
        self.unchanged = unchanged
    }
}
