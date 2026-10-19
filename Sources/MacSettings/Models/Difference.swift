//
//  Difference.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One setting that is not the same on both sides of a diff.
public struct Difference: Codable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let group: String
    /// In words; `not recorded` when one side does not have it.
    public let from: String
    public let to: String

    public init(id: String, label: String, group: String, from: String, to: String) {
        self.id = id
        self.label = label
        self.group = group
        self.from = from
        self.to = to
    }
}
