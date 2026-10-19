//
//  SkipKind.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Why a planned change will not be made.
public enum SkipKind: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    /// This catalogue has no such id.
    case unknown
    /// The catalogue marks it read-only; System Settings can change it.
    case notWritable = "not_writable"
    /// A configuration profile (MDM, Screen Time) sets it.
    case locked
    /// Not probed on this macOS version; `--unverified` allows it.
    case unverified
    /// The value does not fit the setting.
    case invalidValue = "invalid_value"
    /// The app named for a default-app is not installed here.
    case appMissing = "app_missing"
}
