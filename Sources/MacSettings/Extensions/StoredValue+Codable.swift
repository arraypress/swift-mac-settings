//
//  StoredValue+Codable.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

extension StoredValue: Codable {

    enum CodingKeys: String, CodingKey, CaseIterable {
        case absent, bool, int, real, string, plist
    }

    /// One key naming the type — `{"int": 1}`, `{"bool": true}`,
    /// `{"absent": true}` — so the journal keeps what the plist kept.
    public init(from decoder: any Decoder) throws {
        try StrictKeys.check(decoder, allowed: CodingKeys.allCases.map(\.rawValue), in: "a stored value")
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard c.allKeys.count == 1, let key = c.allKeys.first else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath,
                                                                    debugDescription: "a stored value has exactly one key"))
        }
        switch key {
        case .absent: self = .absent
        case .bool: self = .bool(try c.decode(Bool.self, forKey: .bool))
        case .int: self = .int(try c.decode(Int.self, forKey: .int))
        case .real: self = .real(try c.decode(Double.self, forKey: .real))
        case .string: self = .string(try c.decode(String.self, forKey: .string))
        case .plist: self = .plist(try c.decode(Data.self, forKey: .plist))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .absent: try c.encode(true, forKey: .absent)
        case .bool(let value): try c.encode(value, forKey: .bool)
        case .int(let value): try c.encode(value, forKey: .int)
        case .real(let value): try c.encode(value, forKey: .real)
        case .string(let value): try c.encode(value, forKey: .string)
        case .plist(let value): try c.encode(value, forKey: .plist)
        }
    }
}
