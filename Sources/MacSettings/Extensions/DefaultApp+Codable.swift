//
//  DefaultApp+Codable.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

extension DefaultApp: Codable {

    enum CodingKeys: String, CodingKey, CaseIterable {
        case id, label, kind, targets
        case defaultApp = "default"
        case consent, note, verified
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let id = (try? c.decode(String.self, forKey: .id)) ?? "?"
        try StrictKeys.check(decoder, allowed: CodingKeys.allCases.map(\.rawValue), in: "default app \(id)")
        self.init(
            id: try c.decode(String.self, forKey: .id),
            label: try c.decode(String.self, forKey: .label),
            kind: try c.decode(AppTargetKind.self, forKey: .kind),
            targets: try c.decode([String].self, forKey: .targets),
            defaultApp: try c.decodeIfPresent(String.self, forKey: .defaultApp),
            consent: try c.decodeIfPresent(Bool.self, forKey: .consent) ?? false,
            note: try c.decodeIfPresent(String.self, forKey: .note),
            verified: try c.decode([String].self, forKey: .verified)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(label, forKey: .label)
        try c.encode(kind, forKey: .kind)
        try c.encode(targets, forKey: .targets)
        try c.encodeIfPresent(defaultApp, forKey: .defaultApp)
        try c.encode(consent, forKey: .consent)
        try c.encodeIfPresent(note, forKey: .note)
        try c.encode(verified, forKey: .verified)
    }
}
