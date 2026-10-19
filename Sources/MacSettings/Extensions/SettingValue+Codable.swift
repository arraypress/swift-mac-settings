//
//  SettingValue+Codable.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

extension SettingValue: Codable {

    /// The bare JSON value. A boolean is tried first, so `true` never becomes
    /// 1; a whole number is an int, so `48` and `48.0` both read as 48 and the
    /// setting's type decides.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let value = try? c.decode(Bool.self) { self = .bool(value); return }
        if let value = try? c.decode(Int.self) { self = .int(value); return }
        if let value = try? c.decode(Double.self) { self = .double(value); return }
        if let value = try? c.decode(String.self) { self = .string(value); return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "a value must be true/false, a number or a string")
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .bool(let value): try c.encode(value)
        case .int(let value): try c.encode(value)
        case .double(let value): try c.encode(value)
        case .string(let value): try c.encode(value)
        }
    }
}
