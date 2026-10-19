//
//  Outcome.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What happened to one planned item.
public struct Outcome: Codable, Equatable, Sendable {
    public let item: PlanItem
    public let result: ApplyResult
    public let reason: String?
    /// The journal batch it was recorded in, when anything was written.
    public let batch: String?

    public init(item: PlanItem, result: ApplyResult, reason: String? = nil, batch: String? = nil) {
        self.item = item
        self.result = result
        self.reason = reason
        self.batch = batch
    }
}

/// What `undo` did with one journal entry.
public struct UndoOutcome: Codable, Equatable, Sendable {
    public let entry: JournalEntry
    public let result: UndoResult
    public let reason: String?

    public init(entry: JournalEntry, result: UndoResult, reason: String? = nil) {
        self.entry = entry
        self.result = result
        self.reason = reason
    }
}
