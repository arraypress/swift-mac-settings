//
//  UndoResult.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What `undo` did with one journal entry.
public enum UndoResult: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    /// The value before is back.
    case restored
    /// Changed again since it was written, so it is left alone.
    case conflict
    /// Written back, but reading it gave something else.
    case failed
    /// Handed to macOS, which is asking the person to confirm it.
    case pending
}
