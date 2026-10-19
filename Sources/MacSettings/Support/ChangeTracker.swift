//
//  ChangeTracker.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//
//
//  What `learn` saw, net of noise: keys that change by themselves (heartbeats,
//  timestamps, window positions) are learnt during a quiet baseline and left
//  out of what the toggle is said to have changed.
//

import Foundation

/// Accumulates scan-to-scan changes into one line per key.
public struct ChangeTracker: Sendable {

    private var first: [Place: StoredValue] = [:]
    private var last: [Place: StoredValue] = [:]
    private var counts: [Place: Int] = [:]
    private var order: [Place] = []
    /// Keys that changed during the baseline: never reported.
    public private(set) var noise: Set<Place> = []

    public init() {}

    /// A change seen while nobody was touching anything.
    public mutating func baseline(_ place: Place) { noise.insert(place) }

    /// A change seen while watching.
    public mutating func record(_ place: Place, from: StoredValue, to: StoredValue) {
        guard !noise.contains(place) else { return }
        if first[place] == nil {
            first[place] = from
            order.append(place)
        }
        last[place] = to
        counts[place, default: 0] += 1
    }

    /// One change per key, in the order they first changed.
    public func changes(catalogue: Catalogue?) -> [PreferenceChange] {
        order.compactMap { place in
            guard let from = first[place], let to = last[place] else { return nil }
            return PreferenceChange(place: place, from: from, to: to, times: counts[place] ?? 1,
                                    setting: catalogue?.id(owning: place))
        }
    }
}
