//
//  LoginItem.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// An app that opens at login, as System Events lists it.
public struct LoginItem: Codable, Equatable, Sendable {
    public let name: String
    public let path: String
    public let hidden: Bool

    public init(name: String, path: String, hidden: Bool) {
        self.name = name
        self.path = path
        self.hidden = hidden
    }
}
