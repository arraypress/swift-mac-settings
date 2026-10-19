//
//  HostScope.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Which copy of a domain a key lives in: the one every Mac signed in to the
/// account shares, or this machine's own (`defaults -currentHost`, the files
/// under `~/Library/Preferences/ByHost`).
public enum HostScope: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    case any
    case current
}
