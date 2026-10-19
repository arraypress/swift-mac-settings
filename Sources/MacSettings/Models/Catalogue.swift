//
//  Catalogue.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Every setting this library knows, every default app, and what it will
/// never touch.
public struct Catalogue: Equatable, Sendable {
    /// The catalogue's own revision.
    public let version: Int
    /// Where and when the entries were probed.
    public let probed: String
    public let outOfScope: [OutOfScope]
    public let settings: [Setting]
    public let defaultApps: [DefaultApp]

    public init(version: Int, probed: String, outOfScope: [OutOfScope], settings: [Setting], defaultApps: [DefaultApp]) {
        self.version = version
        self.probed = probed
        self.outOfScope = outOfScope
        self.settings = settings
        self.defaultApps = defaultApps
    }
}
