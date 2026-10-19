//
//  Suggest.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//
//
//  "Did you mean": the ids closest to a mistyped one.
//

import Foundation

enum Suggest {

    /// Up to three ids close to `typed`: containing it, or within a few edits.
    static func closest(_ typed: String, among ids: [String]) -> [String] {
        let lowered = typed.lowercased()
        let containing = ids.filter { $0.contains(lowered) || ($0.split(separator: ".").last.map { lowered.contains($0) } ?? false) }
        if !containing.isEmpty { return Array(containing.prefix(3)) }
        let scored = ids.map { ($0, distance(lowered, $0)) }.filter { $0.1 <= max(2, lowered.count / 4) }
        return scored.sorted { $0.1 < $1.1 || ($0.1 == $1.1 && $0.0 < $1.0) }.prefix(3).map(\.0)
    }

    /// Levenshtein distance.
    static func distance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        guard !a.isEmpty else { return b.count }
        guard !b.isEmpty else { return a.count }
        var previous = Array(0...b.count)
        for i in 1...a.count {
            var current = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                current[j] = Swift.min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            previous = current
        }
        return previous[b.count]
    }
}
