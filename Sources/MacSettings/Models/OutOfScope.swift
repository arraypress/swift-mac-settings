//
//  OutOfScope.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Something this library will never read or write, and why.
public struct OutOfScope: Codable, Equatable, Hashable, Sendable {
    public let name: String
    public let why: String

    public init(name: String, why: String) {
        self.name = name
        self.why = why
    }
}
