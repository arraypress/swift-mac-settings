//
//  Catalogue+Codable.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

extension Catalogue: Codable {

    enum CodingKeys: String, CodingKey, CaseIterable {
        case version, probed, outOfScope, settings, defaultApps
    }

    public init(from decoder: any Decoder) throws {
        try StrictKeys.check(decoder, allowed: CodingKeys.allCases.map(\.rawValue), in: "the catalogue")
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            version: try c.decode(Int.self, forKey: .version),
            probed: try c.decode(String.self, forKey: .probed),
            outOfScope: try c.decode([OutOfScope].self, forKey: .outOfScope),
            settings: try c.decode([Setting].self, forKey: .settings),
            defaultApps: try c.decodeIfPresent([DefaultApp].self, forKey: .defaultApps) ?? []
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(version, forKey: .version)
        try c.encode(probed, forKey: .probed)
        try c.encode(outOfScope, forKey: .outOfScope)
        try c.encode(settings, forKey: .settings)
        try c.encode(defaultApps, forKey: .defaultApps)
    }
}
