//
//  Restart.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What has to start again before a written value takes effect.
///
/// cfprefsd is not one of them: every write here goes THROUGH cfprefsd, so it
/// already holds the new value. Killing it is only ever needed after someone
/// edits a plist file behind its back, which this library never does.
public enum Restart: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    case dock
    case finder
    case systemuiserver
    case controlcenter
    /// Each app reads it when it opens: quit and reopen the apps that matter.
    case apps
    /// Read at login.
    case logout

    /// The process `killall` restarts, for the ones a restart fixes; launchd
    /// starts each again by itself.
    public var process: String? {
        switch self {
        case .dock: "Dock"
        case .finder: "Finder"
        case .systemuiserver: "SystemUIServer"
        case .controlcenter: "ControlCenter"
        case .apps, .logout: nil
        }
    }

    /// What a person should do, in words.
    public var advice: String {
        switch self {
        case .apps: "quit and reopen the apps it affects"
        case .logout: "log out and back in"
        default: "restart \(process ?? rawValue) (killall \(process ?? rawValue))"
        }
    }
}
