//
//  CatalogueCheck.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//
//
//  The rules the catalogue must keep. Run by the tests on every build and by
//  `Catalogue.builtIn()` on every load: a catalogue that breaks one is
//  refused, never half-used. The forbidden list is here, in code, so no
//  catalogue edit can put FileVault or a password key within reach.
//

import AppleShortcuts
import Foundation

enum CatalogueCheck {

    /// Domains never read or written, by prefix: security policy, accounts,
    /// root-owned services, and LaunchServices' own store (default apps go
    /// through its API, never its plist).
    static let forbiddenDomains = [
        "com.apple.security", "com.apple.alf", "com.apple.loginwindow", "com.apple.TCC", "com.apple.SoftwareUpdate",
        "com.apple.TimeMachine", "com.apple.icloud", "MobileMeAccounts", "com.apple.CloudDocs",
        "com.apple.LaunchServices", "com.apple.MCX", "com.apple.applicationaccess", "com.apple.systempolicy",
        "com.apple.SetupAssistant", "com.apple.preferences.sharing",
    ]

    /// Single keys never touched in otherwise ordinary domains.
    static let forbiddenKeys: Set<String> = ["askForPassword", "askForPasswordDelay", "autoLoginUser", "GuestEnabled"]

    /// `group.name`: lowercase words joined by hyphens, one dot.
    static var idPattern: Regex<(Substring, Substring?, Substring?)> { /[a-z0-9]+(-[a-z0-9]+)*\.[a-z0-9]+(-[a-z0-9]+)*/ }

    /// A System Settings pane: an extension id that opens with
    /// `x-apple.systempreferences:<id>`.
    /// A pane's extension id. Bluetooth's alone breaks the pattern (measured:
    /// Bluetooth.appex is `com.apple.BluetoothSettings`).
    static var panePattern: Regex<Substring> { /com\.apple\.[A-Za-z0-9-]+-Settings\.extension|com\.apple\.BluetoothSettings/ }

    /// Whether a place is out of bounds whatever a catalogue says.
    static func isForbidden(_ place: Place) -> Bool {
        forbiddenKeys.contains(place.key)
            || forbiddenDomains.contains { place.domain.lowercased().hasPrefix($0.lowercased()) }
    }

    /// Every problem with the catalogue; empty when it is sound.
    static func problems(_ catalogue: Catalogue) -> [String] {
        var problems: [String] = []
        var seen = Set<String>()
        for setting in catalogue.settings {
            let label = "setting \(setting.id)"
            problems += idProblems(setting.id, group: setting.group, label: label, seen: &seen)
            if setting.label.trimmingCharacters(in: .whitespaces).isEmpty { problems.append("\(label): no label") }
            for place in [Place(domain: setting.domain, key: setting.key, host: setting.host)] + setting.mirrors {
                if place.domain.isEmpty || place.key.isEmpty { problems.append("\(label): empty domain or key") }
                if place.domain.contains("/") || place.domain.hasPrefix("~") || place.domain.hasPrefix(".") {
                    problems.append("\(label): \(place.domain) is a path, not a domain")
                }
                if isForbidden(place) { problems.append("\(label): \(place.domain) \(place.key) is out of scope") }
            }
            if let storage = setting.storage, !(setting.type == .bool && storage == .int) {
                problems.append("\(label): storage is only for booleans kept as integers")
            }
            for choice in setting.choices where Values.coerce(choice.value, to: setting.type) == nil {
                problems.append("\(label): choice \(choice.label) is not a \(setting.type.rawValue)")
            }
            if Set(setting.choices.map { Values.coerce($0.value, to: setting.type) }).count != setting.choices.count {
                problems.append("\(label): duplicate choices")
            }
            if setting.min != nil || setting.max != nil {
                if setting.type != .int && setting.type != .float { problems.append("\(label): min and max are for numbers") }
                if let min = setting.min, let max = setting.max, min > max { problems.append("\(label): min is above max") }
            }
            if let value = setting.defaultValue {
                if let reason = Values.problem(with: value, for: setting) { problems.append("\(label): default \(reason)") }
            }
            if setting.verified.isEmpty { problems.append("\(label): never probed (verified is empty)") }
            for version in setting.verified where Int(version) == nil { problems.append("\(label): \(version) is not a macOS major version") }
            if setting.writable == (setting.readOnlyReason != nil) {
                problems.append("\(label): a read-only setting says why, and only a read-only one")
            }
            if let pane = setting.pane, pane.wholeMatch(of: panePattern) == nil { problems.append("\(label): \(pane) is not a settings pane id") }
            if Set(setting.restart).count != setting.restart.count { problems.append("\(label): restart repeats itself") }
            problems += controlProblems(setting, label: label)
        }
        for app in catalogue.defaultApps {
            let label = "default app \(app.id)"
            problems += idProblems(app.id, group: DefaultApp.group, label: label, seen: &seen)
            if app.targets.isEmpty { problems.append("\(label): no targets") }
            for target in app.targets {
                switch app.kind {
                case .scheme:
                    if target.wholeMatch(of: /[a-z][a-z0-9+.-]*/) == nil { problems.append("\(label): \(target) is not a URL scheme") }
                case .type:
                    if !target.contains(".") { problems.append("\(label): \(target) is not a content type") }
                }
            }
            if app.verified.isEmpty { problems.append("\(label): never probed (verified is empty)") }
        }
        return problems
    }

    /// A helper-written setting names a real helper, a field that helper
    /// reads, and a reader that exists — and only it uses the `(macOS)` domain.
    static func controlProblems(_ setting: Setting, label: String) -> [String] {
        guard let control = setting.control else {
            return setting.domain == liveDomain ? ["\(label): the \(liveDomain) domain is for settings with a reader"] : []
        }
        var problems: [String] = []
        let helpers = (try? HelperCatalogue.builtIn()) ?? HelperCatalogue(helpers: [])
        if control.helper == nil {
            if setting.writable { problems.append("\(label): a setting with no helper is read-only") }
        } else if let helper = helpers.helper(control.helper!) {
            let fields = Set(helper.input.map(\.name))
            for key in control.keys.values.sorted() where !fields.contains(key) {
                problems.append("\(label): \(helper.id) takes no \(key)")
            }
            if let field = control.field, !fields.contains(field) { problems.append("\(label): \(helper.id) takes no \(field)") }
            if control.keys.isEmpty == (control.field == nil) { problems.append("\(label): a control has keys or a field, not both or neither") }
            if setting.type == .bool, !control.keys.isEmpty, Set(control.keys.keys) != ["on", "off"] {
                problems.append("\(label): a switch's keys are on and off")
            }
            for choice in setting.choices where !control.keys.isEmpty {
                if case .string(let value) = choice.value, control.keys[value] == nil { problems.append("\(label): no key for \(value)") }
            }
        } else {
            problems.append("\(label): no helper \(control.helper!)")
        }
        if let probe = control.probe {
            if !SystemProbes.names.contains(probe) { problems.append("\(label): no reader \(probe)") }
            if setting.domain != liveDomain || setting.key != probe {
                problems.append("\(label): a setting with a reader is \(liveDomain) / \(probe)")
            }
        } else if setting.domain == liveDomain {
            problems.append("\(label): \(liveDomain) needs a reader")
        }
        if !setting.writable, control.helper != nil { problems.append("\(label): a setting with a helper is writable") }
        return problems
    }

    /// The pseudo-domain of settings read from the OS rather than a preference.
    static let liveDomain = "(macOS)"

    private static func idProblems(_ id: String, group: String, label: String, seen: inout Set<String>) -> [String] {
        var problems: [String] = []
        if id.wholeMatch(of: idPattern) == nil { problems.append("\(label): id is not group.name in lowercase") }
        if !seen.insert(id).inserted { problems.append("\(label): duplicate id") }
        if let prefix = id.split(separator: ".").first, String(prefix) != Groups.slug(group) {
            problems.append("\(label): id does not start with its group (\(Groups.slug(group)))")
        }
        return problems
    }
}
