//
//  PlanStatus.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What a plan says will happen to one setting.
public enum PlanStatus: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    case change
    case unchanged
    case skipped
}
