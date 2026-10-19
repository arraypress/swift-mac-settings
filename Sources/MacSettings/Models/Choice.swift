//
//  Choice.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One allowed value and what to call it.
public struct Choice: Codable, Equatable, Hashable, Sendable {
    public let value: SettingValue
    public let label: String

    public init(value: SettingValue, label: String) {
        self.value = value
        self.label = label
    }
}
