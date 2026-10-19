//
//  PreferenceChange.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A key that changed while `learn` watched, first value to last.
public struct PreferenceChange: Codable, Equatable, Sendable {
    public let place: Place
    public let from: StoredValue
    public let to: StoredValue
    /// How many times it changed in the window.
    public let times: Int
    /// The catalogue id, when the catalogue already knows this key.
    public let setting: String?

    public init(place: Place, from: StoredValue, to: StoredValue, times: Int, setting: String?) {
        self.place = place
        self.from = from
        self.to = to
        self.times = times
        self.setting = setting
    }
}
