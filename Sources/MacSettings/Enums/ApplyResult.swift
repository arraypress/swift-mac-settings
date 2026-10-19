//
//  ApplyResult.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What happened when a planned change was made.
public enum ApplyResult: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    /// Written and read back as written.
    case applied
    case unchanged
    case skipped
    /// Written, but reading it back gave something else.
    case failed
    /// Handed to macOS, which is asking the person to confirm it.
    case pending
}
