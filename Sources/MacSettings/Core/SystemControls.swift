//
//  SystemControls.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//
//  The settings only Shortcuts can change: their readers, and the helper
//  shortcuts that write them. A write is believed only once the reader shows
//  it; a setting this Mac cannot read back is not written at all.
//

import AppleShortcuts
import Foundation

/// What controlled settings need from the outside world.
public protocol SystemControls: Sendable {
    /// The value an OS reader gives, or why it cannot be read here.
    func read(probe: String) -> ProbeReading
    /// Runs a helper shortcut with `input`.
    func run(helper: String, input: [String: PlistValue]) throws
}

/// A reader's answer.
public enum ProbeReading: Equatable, Sendable {
    case value(SettingValue)
    /// Not readable on this Mac, and why — "True Tone is not available on this display".
    case unavailable(String)
}

/// This Mac's readers and helper shortcuts.
public struct LiveSystemControls: SystemControls {
    public let helpers: HelperCatalogue
    public let host: any HelperHost
    public let onWaiting: (@Sendable () -> Void)?

    public init(helpers: HelperCatalogue? = nil, host: any HelperHost = LiveHelperHost(), onWaiting: (@Sendable () -> Void)? = nil) {
        self.helpers = helpers ?? ((try? HelperCatalogue.builtIn()) ?? HelperCatalogue(helpers: []))
        self.host = host
        self.onWaiting = onWaiting
    }

    public func read(probe: String) -> ProbeReading { SystemProbes.read(probe) }

    public func run(helper: String, input: [String: PlistValue]) throws {
        guard let found = helpers.helper(helper) else {
            throw SettingsError.helper(id: helper, reason: "this build has no helper \(helper)", remedy: "reinstall settings")
        }
        _ = try found.run(input, host: host, onWaiting: onWaiting)
    }
}

enum ControlInput {

    /// The key a value goes under: `on`/`off` for a switch, the stored text for a choice.
    static func key(_ value: SettingValue) -> String {
        switch value {
        case .bool(let on): on ? "on" : "off"
        case .int(let n): String(n)
        case .double(let d): String(d)
        case .string(let s): s
        }
    }

    /// The helper's input for setting `control` to `value`, or `nil` when the
    /// helper has no branch for it.
    static func input(_ control: Control, value: SettingValue) -> [String: PlistValue]? {
        if !control.keys.isEmpty {
            return control.keys[key(value)].map { [$0: .bool(true)] }
        }
        guard let field = control.field else { return nil }
        switch value {
        case .bool(let on): return [field: .bool(on)]
        case .int(let number): return [field: .double(Double(number))]
        case .double(let number): return [field: .double(number)]
        case .string(let text): return [field: .string(text)]
        }
    }
}
