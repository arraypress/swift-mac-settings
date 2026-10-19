//
//  DefaultApp.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A default-app choice: which app opens a URL scheme or a content type.
/// LaunchServices keeps these, not a preferences key.
public struct DefaultApp: Equatable, Hashable, Sendable {
    /// `default-apps.name`.
    public let id: String
    public let label: String
    public let kind: AppTargetKind
    /// Every scheme or type it covers; all are set together (`http` and `https`).
    public let targets: [String]
    /// The bundle id a fresh Mac uses, when that is known.
    public let defaultApp: String?
    /// macOS asks the person to confirm a change.
    public let consent: Bool
    public let note: String?
    public let verified: [String]

    public init(id: String, label: String, kind: AppTargetKind, targets: [String], defaultApp: String? = nil,
                consent: Bool = false, note: String? = nil, verified: [String]) {
        self.id = id
        self.label = label
        self.kind = kind
        self.targets = targets
        self.defaultApp = defaultApp
        self.consent = consent
        self.note = note
        self.verified = verified
    }

    /// The group every default app is listed under.
    public static let group = "Default apps"
}
