//
//  Place.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Where one value lives: a preferences domain, a key in it, and which host's
/// copy. `NSGlobalDomain` is the global domain (`defaults -g`).
public struct Place: Equatable, Hashable, Sendable {
    public let domain: String
    public let key: String
    public let host: HostScope

    public init(domain: String, key: String, host: HostScope = .any) {
        self.domain = domain
        self.key = key
        self.host = host
    }
}
