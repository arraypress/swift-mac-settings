//
//  JournalEntry.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One write, remembered so `undo` can put the value before back exactly.
///
/// A preference write carries `place`, `before` and `after`; a default-app
/// change carries `target`, `appBefore` and `appAfter`.
public struct JournalEntry: Codable, Equatable, Sendable {
    public let id: String
    /// The `set` or `apply` run it belonged to; `undo` restores a whole batch.
    public let batch: String
    /// The catalogue id.
    public let setting: String
    public let at: Date
    public let place: Place?
    public let before: StoredValue?
    public let after: StoredValue?
    public let kind: AppTargetKind?
    public let target: String?
    public let appBefore: String?
    public let appAfter: String?
    /// Set once `undo` has put it back.
    public var restoredAt: Date?

    public init(id: String, batch: String, setting: String, at: Date, place: Place? = nil, before: StoredValue? = nil,
                after: StoredValue? = nil, kind: AppTargetKind? = nil, target: String? = nil, appBefore: String? = nil,
                appAfter: String? = nil, restoredAt: Date? = nil) {
        self.id = id
        self.batch = batch
        self.setting = setting
        self.at = at
        self.place = place
        self.before = before
        self.after = after
        self.kind = kind
        self.target = target
        self.appBefore = appBefore
        self.appAfter = appAfter
        self.restoredAt = restoredAt
    }
}
