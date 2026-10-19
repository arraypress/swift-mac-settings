//
//  Focus.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//
//  The Focus that is on, and turning one on or off — through two helper
//  shortcuts, since nothing else may: "settings · Get Focus" and
//  "settings · Set Focus". A change is believed only when Get Focus says so.
//

import AppleShortcuts
import Foundation

/// What Focus needs from the outside world.
public protocol FocusHost: Sendable {
    /// `ModeConfigurations.json`, or `nil` when it cannot be read.
    func modesData() -> Data?
    /// `Assertions.json`, or `nil`.
    func assertionsData() -> Data?
    /// The Focus that is on, by name; `nil` for none.
    func activeFocus() throws -> String?
    /// Turns `name` on or off; `until` as the helper takes it.
    func setFocus(name: String, on: Bool, until: String?) throws
}

/// This Mac: the Do Not Disturb store's files and the two helpers.
public struct LiveFocusHost: FocusHost {
    public let helpers: HelperCatalogue
    public let host: any HelperHost
    public let onWaiting: (@Sendable () -> Void)?

    public init(helpers: HelperCatalogue, host: any HelperHost = LiveHelperHost(), onWaiting: (@Sendable () -> Void)? = nil) {
        self.helpers = helpers
        self.host = host
        self.onWaiting = onWaiting
    }

    public func modesData() -> Data? { try? Data(contentsOf: FocusFiles.folder.appendingPathComponent("ModeConfigurations.json")) }
    public func assertionsData() -> Data? { try? Data(contentsOf: FocusFiles.folder.appendingPathComponent("Assertions.json")) }

    public func activeFocus() throws -> String? {
        let result = try helpers["settings.focus-get"].run(host: host, onWaiting: onWaiting)
        let name = String(decoding: result.output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    public func setFocus(name: String, on: Bool, until: String?) throws {
        var input: [String: PlistValue] = ["focus": .string(name), "on": .bool(on)]
        if let until { input["until"] = .string(until) }
        _ = try helpers["settings.focus-set"].run(input, host: host, onWaiting: onWaiting)
    }
}

public enum Focus {

    /// The helpers Focus uses.
    public static let helperIDs = ["settings.focus-get", "settings.focus-set"]

    /// The Focus now: Get Focus's answer, the store's, and every mode.
    public static func read(host: any FocusHost) throws -> FocusReading {
        let modes = host.modesData().map(FocusFiles.modes) ?? []
        let assertion = host.assertionsData().flatMap(FocusFiles.assertion)
        let asserted = assertion.map { found in modes.first { $0.id == found.mode } ?? FocusMode(id: found.mode, name: found.mode) }
        return FocusReading(active: try host.activeFocus(), asserted: asserted, lifetime: assertion?.lifetime, modes: modes)
    }

    /// The plan for turning `name` on (until `until`) or off. `name` `nil`
    /// with `on: false` means whichever Focus is on. Reads only.
    public static func plan(name: String?, on: Bool, until: Date?, host: any FocusHost, now: Date = Date()) throws -> FocusPlan {
        let reading = try read(host: host)
        if let until, until <= now {
            throw SettingsError.invalidValue(id: "focus", reason: "--until must be in the future")
        }
        if !on, until != nil { throw SettingsError.invalidValue(id: "focus", reason: "--until is for turning a Focus on") }
        let typed = name ?? reading.active
        guard let typed else {
            guard !on else { throw SettingsError.invalidValue(id: "focus", reason: "name the Focus to turn on") }
            // Off, with nothing on: already as asked.
            let none = FocusMode(id: "", name: "")
            return FocusPlan(from: nil, to: nil, mode: none, on: false, until: nil, unchanged: true)
        }
        guard let mode = FocusFiles.mode(named: typed, in: reading.modes) ?? (name == nil ? FocusMode(id: typed, name: typed) : nil) else {
            let known = reading.modes.map(\.name).joined(separator: ", ")
            throw SettingsError.invalidValue(id: "focus", reason: "no Focus called \(typed)" + (known.isEmpty ? "" : " — this Mac has \(known)"))
        }
        let isOn = same(reading.active, mode.name)
        if on {
            return FocusPlan(from: reading.active, to: mode.name, mode: mode, on: true, until: until,
                             unchanged: isOn && until == nil)
        }
        return FocusPlan(from: reading.active, to: isOn ? nil : reading.active, mode: mode, on: false, until: nil, unchanged: !isOn)
    }

    /// Runs the plan, then reads Get Focus until it shows the plan's `to`.
    ///
    /// - Returns: The Focus as it reads back.
    /// - Throws: ``SettingsError/notConfirmed(id:expected:found:changed:reason:)``
    ///   when it never does.
    public static func apply(_ plan: FocusPlan, host: any FocusHost, attempts: Int = 20,
                             interval: TimeInterval = 0.25) throws -> FocusReading {
        guard !plan.unchanged else { return try read(host: host) }
        var failure: Error?
        do {
            try host.setFocus(name: plan.mode.name, on: plan.on, until: plan.until.map { FocusFiles.helperDate($0) })
        } catch let error as HelperError {
            // Refused before running: nothing happened.
            throw SettingsError.helper(id: "focus", reason: error.localizedDescription, remedy: error.remedy)
        } catch {
            failure = error
        }
        var seen: String?
        for attempt in 0..<attempts {
            seen = try? host.activeFocus()
            if same(seen, plan.to) { return try read(host: host) }
            // A failed run is not waited out — unless it timed out, when it may still land.
            if let failure, !isTimeout(failure), attempt >= 2 { break }
            Thread.sleep(forTimeInterval: interval)
        }
        throw SettingsError.notConfirmed(id: "focus", expected: plan.to ?? "no Focus", found: seen ?? "no Focus",
                                         changed: !same(seen, plan.from), reason: failure.map { "The shortcut failed: \($0.localizedDescription)" })
    }

    static func isTimeout(_ error: Error) -> Bool {
        if case .timedOut = error as? ShortcutsError { return true }
        return false
    }

    static func same(_ lhs: String?, _ rhs: String?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil): true
        case let (l?, r?): l.compare(r, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        default: false
        }
    }
}
