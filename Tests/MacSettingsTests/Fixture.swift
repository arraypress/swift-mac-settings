//
//  Fixture.swift
//  MacSettingsTests
//
//  Created by David Sherlock on 2026.
//
//
//  Everything a test writes goes to ONE scratch domain,
//  com.example.settings-tests (and its ByHost copy), under keys unique to the
//  test — never to the Dock, Finder or any real domain. Every key is removed
//  again when the fixture is torn down. Profiles are fixture plists in a
//  temporary folder, the journal a temporary file, LaunchServices a fake.
//

import Foundation
@testable import MacSettings

let scratchDomain = "com.example.settings-tests"

/// A test's own keys, catalogue, profiles folder and journal.
final class Fixture {

    let tag = String(UUID().uuidString.prefix(8)).lowercased()
    let folder: URL
    let store = CFPreferenceStore()
    let apps = FakeApps()
    private(set) var places: [Place] = []

    init() throws {
        folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("settings-tests-\(tag)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    deinit {
        for place in places { store.write(.absent, to: place) }
        try? FileManager.default.removeItem(at: folder)
    }

    /// A unique key in the scratch domain, removed at teardown.
    func place(_ name: String, host: HostScope = .any) -> Place {
        let place = Place(domain: scratchDomain, key: "\(name)-\(tag)", host: host)
        places.append(place)
        return place
    }

    var managedRoot: URL { folder.appendingPathComponent("Managed Preferences") }
    var journal: URL { folder.appendingPathComponent("journal.json") }

    func context(system: String = "27.0.1", allowUnverified: Bool = false) -> SettingsContext {
        SettingsContext(store: store, apps: apps, managed: ManagedPreferences(root: managedRoot, user: "tester"),
                        journal: journal, system: SystemVersion(version: system, build: "TEST"),
                        allowUnverified: allowUnverified, appTimeout: 1)
    }

    /// A catalogued setting on a scratch key.
    func setting(_ name: String, type: SettingType = .bool, storage: SettingType? = nil, choices: [Choice] = [],
                 min: Double? = nil, max: Double? = nil, defaultValue: SettingValue? = .bool(false),
                 restart: [Restart] = [], host: HostScope = .any, mirrors: [String] = [], writable: Bool = true,
                 verified: [String] = ["27"], group: String = "Tests") -> Setting {
        let main = place(name, host: host)
        return Setting(id: "\(Groups.slug(group)).\(name)", label: "Test \(name)", group: group, domain: main.domain,
                       key: main.key, host: host, type: type, storage: storage, choices: choices, min: min, max: max,
                       defaultValue: defaultValue, restart: restart, pane: "com.apple.Desktop-Settings.extension",
                       mirrors: mirrors.map { place($0) }, writable: writable,
                       readOnlyReason: writable ? nil : "fixture says so", verified: verified)
    }

    func catalogue(_ settings: [Setting], apps: [DefaultApp] = []) -> Catalogue {
        Catalogue(version: 1, probed: "tests", outOfScope: [], settings: settings, defaultApps: apps)
    }

    /// A profile that sets `keys` in `domain`, for the user or the computer.
    func manage(_ domain: String, keys: [String: Any], forUser: Bool = true) throws {
        let dir = forUser ? managedRoot.appendingPathComponent("tester") : managedRoot
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = domain == "NSGlobalDomain" ? ".GlobalPreferences" : domain
        let data = try PropertyListSerialization.data(fromPropertyList: keys, format: .xml, options: 0)
        try data.write(to: dir.appendingPathComponent(file + ".plist"))
    }

    /// What a separate process — `defaults` — reads for `place`.
    func defaultsRead(_ place: Place) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = (place.host == .current ? ["-currentHost"] : []) + ["read", place.domain, place.key]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { return nil }
        return String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Writes `args` with `defaults write` from a separate process.
    func defaultsWrite(_ place: Place, _ args: [String]) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = (place.host == .current ? ["-currentHost"] : []) + ["write", place.domain, place.key] + args
        try? task.run()
        task.waitUntilExit()
    }
}

/// LaunchServices, faked: handlers in a dictionary, installed apps in a list.
final class FakeApps: AppStore, @unchecked Sendable {
    private let lock = NSLock()
    private var handlers: [String: String] = [:]
    var installed: [AppChoice] = [
        AppChoice(bundleID: "com.example.browser", name: "Example Browser", path: "/Applications/Example Browser.app"),
        AppChoice(bundleID: "com.example.other", name: "Other Browser", path: "/Applications/Other Browser.app"),
    ]
    /// What `setHandler` answers.
    var answer: AppWrite = .done
    private(set) var calls: [String] = []

    func preset(_ target: String, _ bundleID: String) { lock.lock(); handlers[target] = bundleID; lock.unlock() }

    func handler(kind: AppTargetKind, target: String) -> String? { lock.lock(); defer { lock.unlock() }; return handlers[target] }
    func candidates(kind: AppTargetKind, target: String) -> [AppChoice] { installed }
    func app(bundleID: String) -> AppChoice? { installed.first { $0.bundleID == bundleID } }
    func setHandler(_ bundleID: String, kind: AppTargetKind, target: String, timeout: Double) -> AppWrite {
        lock.lock(); defer { lock.unlock() }
        calls.append("\(target)=\(bundleID)")
        if answer == .done { handlers[target] = bundleID }
        return answer
    }
}

/// A default-app entry for the fake.
func browserEntry() -> DefaultApp {
    DefaultApp(id: "default-apps.browser", label: "Web browser", kind: .scheme, targets: ["http", "https"],
               defaultApp: "com.example.browser", consent: true, verified: ["27"])
}
