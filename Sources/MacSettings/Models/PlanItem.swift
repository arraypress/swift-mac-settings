//
//  PlanItem.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What a plan will do to one setting or default app, and why not when it won't.
public struct PlanItem: Codable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let status: PlanStatus
    public let skip: SkipKind?
    /// Why it is skipped, in words.
    public let reason: String?
    /// The value now and after, in words.
    public let from: String
    public let to: String
    /// The preference writes, main key first then its mirrors.
    public let writes: [PlannedWrite]
    /// The LaunchServices change, for a default app.
    public let app: PlannedApp?
    /// The helper-shortcut change, for a setting only Shortcuts can change.
    public let control: PlannedControl?
    public let restart: [Restart]
    /// The System Settings URL to change it by hand, when it is skipped.
    public let paneURL: String?

    public init(id: String, label: String, status: PlanStatus, skip: SkipKind? = nil, reason: String? = nil,
                from: String, to: String, writes: [PlannedWrite] = [], app: PlannedApp? = nil,
                restart: [Restart] = [], paneURL: String? = nil, control: PlannedControl? = nil) {
        self.id = id
        self.label = label
        self.status = status
        self.skip = skip
        self.reason = reason
        self.from = from
        self.to = to
        self.writes = writes
        self.app = app
        self.control = control
        self.restart = restart
        self.paneURL = paneURL
    }
}

/// One key: what it holds now, and what it will hold.
public struct PlannedWrite: Codable, Equatable, Sendable {
    public let place: Place
    public let before: StoredValue
    public let after: StoredValue

    public init(place: Place, before: StoredValue, after: StoredValue) {
        self.place = place
        self.before = before
        self.after = after
    }
}

/// A default-app change: the bundle id now (per target) and the one to set.
public struct PlannedApp: Codable, Equatable, Sendable {
    public let kind: AppTargetKind
    public let targets: [String]
    /// The handler now, per target, in `targets` order; `nil` when none.
    public let before: [String?]
    public let after: String
    public let consent: Bool

    public init(kind: AppTargetKind, targets: [String], before: [String?], after: String, consent: Bool) {
        self.kind = kind
        self.targets = targets
        self.before = before
        self.after = after
        self.consent = consent
    }
}
