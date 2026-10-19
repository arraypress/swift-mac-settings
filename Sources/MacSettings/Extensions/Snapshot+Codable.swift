//
//  Snapshot+Codable.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

extension Snapshot: Codable {

    enum CodingKeys: String, CodingKey, CaseIterable {
        case kind, version, macOS, build, takenAt, catalogue, settings, defaultApps
    }

    /// Strict about the shape — an unknown key or a missing `kind` is refused,
    /// so a typo never silently drops a setting — and lenient about content:
    /// a hand-written file needs only `kind` and `settings`.
    public init(from decoder: any Decoder) throws {
        try StrictKeys.check(decoder, allowed: CodingKeys.allCases.map(\.rawValue), in: "the snapshot")
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            kind: try c.decode(String.self, forKey: .kind),
            version: try c.decodeIfPresent(Int.self, forKey: .version) ?? 1,
            macOS: try c.decodeIfPresent(String.self, forKey: .macOS),
            build: try c.decodeIfPresent(String.self, forKey: .build),
            takenAt: try c.decodeIfPresent(String.self, forKey: .takenAt),
            catalogue: try c.decodeIfPresent(Int.self, forKey: .catalogue),
            settings: try c.decodeIfPresent([SnapshotSetting].self, forKey: .settings) ?? [],
            defaultApps: try c.decodeIfPresent([SnapshotApp].self, forKey: .defaultApps) ?? []
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(kind, forKey: .kind)
        try c.encode(version, forKey: .version)
        try c.encodeIfPresent(macOS, forKey: .macOS)
        try c.encodeIfPresent(build, forKey: .build)
        try c.encodeIfPresent(takenAt, forKey: .takenAt)
        try c.encodeIfPresent(catalogue, forKey: .catalogue)
        try c.encode(settings, forKey: .settings)
        try c.encode(defaultApps, forKey: .defaultApps)
    }
}

extension SnapshotSetting: Codable {

    enum CodingKeys: String, CodingKey, CaseIterable {
        case id, label, group, value, set, locked
    }

    public init(from decoder: any Decoder) throws {
        try StrictKeys.check(decoder, allowed: CodingKeys.allCases.map(\.rawValue), in: "a snapshot setting")
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try c.decode(String.self, forKey: .id),
                  label: try c.decodeIfPresent(String.self, forKey: .label),
                  group: try c.decodeIfPresent(String.self, forKey: .group),
                  value: try c.decodeIfPresent(SettingValue.self, forKey: .value),
                  set: try c.decodeIfPresent(Bool.self, forKey: .set),
                  locked: try c.decodeIfPresent(Bool.self, forKey: .locked))
    }

    /// `value` is always written, as `null` when not set, so the file says
    /// "not set" rather than leaving the reader to guess.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(label, forKey: .label)
        try c.encodeIfPresent(group, forKey: .group)
        try c.encode(value, forKey: .value)
        try c.encodeIfPresent(set, forKey: .set)
        if locked == true { try c.encode(true, forKey: .locked) }
    }
}
