//
//  SettingsContext.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Darwin
import Foundation

/// Everything a read or a write needs from the outside world, so tests can
/// point it at a scratch domain, fixture profiles and a temporary journal.
public struct SettingsContext: Sendable {
    public var store: any PreferenceStore
    public var apps: any AppStore
    public var managed: ManagedPreferences
    /// The undo journal.
    public var journal: URL
    public var system: SystemVersion
    /// Write settings not probed on this macOS version too.
    public var allowUnverified: Bool
    /// How long to wait for macOS to answer a default-app change.
    public var appTimeout: Double
    /// The settings only Shortcuts can change.
    public var controls: any SystemControls
    /// Read-backs after a helper write, and the pause between them.
    public var controlAttempts = 20
    public var controlInterval: TimeInterval = 0.25

    public init(store: any PreferenceStore, apps: any AppStore, managed: ManagedPreferences, journal: URL,
                system: SystemVersion, allowUnverified: Bool = false, appTimeout: Double = 30,
                controls: any SystemControls = LiveSystemControls()) {
        self.store = store
        self.apps = apps
        self.managed = managed
        self.journal = journal
        self.system = system
        self.allowUnverified = allowUnverified
        self.appTimeout = appTimeout
        self.controls = controls
    }

    /// This Mac, this user.
    public static func live(journal: URL? = nil, allowUnverified: Bool = false) -> SettingsContext {
        SettingsContext(store: CFPreferenceStore(), apps: WorkspaceAppStore(), managed: ManagedPreferences(),
                        journal: journal ?? defaultJournal, system: .current, allowUnverified: allowUnverified)
    }

    /// `~/Library/Application Support/settings/journal.json`.
    public static var defaultJournal: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/settings/journal.json")
    }
}

public extension SystemVersion {

    /// The macOS this process runs on.
    static var current: SystemVersion {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        var size = 0
        sysctlbyname("kern.osversion", nil, &size, nil, 0)
        var bytes = [CChar](repeating: 0, count: max(size, 1))
        sysctlbyname("kern.osversion", &bytes, &size, nil, 0)
        let build = String(decoding: bytes.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
        return SystemVersion(version: "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)", build: build.isEmpty ? nil : build)
    }
}
