//
//  Place+Codable.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

extension Place: Codable {

    enum CodingKeys: String, CodingKey, CaseIterable {
        case domain, key, host
    }

    public init(from decoder: any Decoder) throws {
        try StrictKeys.check(decoder, allowed: CodingKeys.allCases.map(\.rawValue), in: "a place")
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(domain: try c.decode(String.self, forKey: .domain),
                  key: try c.decode(String.self, forKey: .key),
                  host: try c.decodeIfPresent(HostScope.self, forKey: .host) ?? .any)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(domain, forKey: .domain)
        try c.encode(key, forKey: .key)
        try c.encode(host, forKey: .host)
    }
}
