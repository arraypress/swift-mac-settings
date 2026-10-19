//
//  SettingType.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// The kind of value a setting holds, as a person would set it.
///
/// Not always the kind macOS stores: a few booleans live as the integers 0
/// and 1 (``Setting/storage``), and a real may arrive as an integer. Reading
/// converts; writing stores the kind System Settings itself writes.
public enum SettingType: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    case bool
    case int
    case float
    case string
}
