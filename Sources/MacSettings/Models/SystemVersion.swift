//
//  SystemVersion.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// The macOS a reading was taken on.
public struct SystemVersion: Codable, Equatable, Hashable, Sendable {
    /// `27.0.1`.
    public let version: String
    /// `26A434`, when known.
    public let build: String?

    public init(version: String, build: String? = nil) {
        self.version = version
        self.build = build
    }

    /// The major version, which is what ``Setting/verified`` lists: `27`.
    public var major: String { String(version.split(separator: ".").first ?? Substring(version)) }
}
