//
//  Catalogue+BuiltIn.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

public extension Catalogue {

    /// The catalogue compiled into this library, read strictly and checked.
    static func builtIn() throws(SettingsError) -> Catalogue {
        try decode(Data(CatalogueData.json.utf8))
    }

    /// Reads a catalogue: unknown keys, bad values and broken entries all refuse.
    static func decode(_ data: Data) throws(SettingsError) -> Catalogue {
        let catalogue: Catalogue
        do {
            catalogue = try JSONDecoder().decode(Catalogue.self, from: data)
        } catch {
            throw .invalidCatalogue(String(describing: error))
        }
        let problems = CatalogueCheck.problems(catalogue)
        guard problems.isEmpty else { throw .invalidCatalogue(problems.joined(separator: "; ")) }
        return catalogue
    }

    /// Every problem with this catalogue; empty when it is sound.
    var problems: [String] { CatalogueCheck.problems(self) }

    /// Every id, settings first, in catalogue order.
    var ids: [String] { settings.map(\.id) + defaultApps.map(\.id) }

    /// The groups, in catalogue order, default apps last.
    var groups: [String] {
        var seen = Set<String>()
        return (settings.map(\.group) + (defaultApps.isEmpty ? [] : [DefaultApp.group])).filter { seen.insert($0).inserted }
    }

    func setting(_ id: String) -> Setting? { settings.first { $0.id == id } }

    func defaultApp(_ id: String) -> DefaultApp? { defaultApps.first { $0.id == id } }

    /// Throws with the nearest ids when `id` names nothing.
    func requireID(_ id: String) throws(SettingsError) {
        guard setting(id) == nil, defaultApp(id) == nil else { return }
        throw .unknownSetting(id, suggestions: Suggest.closest(id, among: ids))
    }

    /// The group a person typed, as the catalogue spells it.
    func group(named typed: String) throws(SettingsError) -> String {
        guard let group = groups.first(where: { Groups.matches(typed, group: $0) }) else {
            throw .unknownGroup(typed, groups: groups)
        }
        return group
    }

    /// The catalogue id that owns `place` (its main key or a mirror).
    func id(owning place: Place) -> String? {
        settings.first { setting in
            setting.places.contains { $0 == place }
        }?.id
    }

    /// Whether `place` is one this library refuses to touch, whatever any
    /// catalogue says.
    static func isOutOfScope(_ place: Place) -> Bool { CatalogueCheck.isForbidden(place) }
}

public extension Setting {

    /// The main key.
    var place: Place { Place(domain: domain, key: key, host: host) }

    /// The main key, then its mirrors.
    var places: [Place] { [place] + mirrors }

    /// `x-apple.systempreferences:…`, when there is a pane.
    var paneURL: String? { PaneURL.url(for: pane) }

    /// What it accepts, in words.
    var accepts: String { Values.expectation(for: self) }

    /// Whether it was probed on `system`'s major version.
    func isVerified(on system: SystemVersion) -> Bool { verified.contains(system.major) }

    /// A value in words.
    func display(_ value: SettingValue?) -> String { Values.display(value, for: self) }

    /// Reads typed text as a value; `nil` means "default" (remove the key).
    func parse(_ text: String) throws(SettingsError) -> SettingValue? { try Values.parse(text, for: self) }

    /// The `defaults` command that reads it, for people checking by hand.
    var defaultsCommand: String {
        let flag = host == .current ? "-currentHost " : ""
        let target = domain == "NSGlobalDomain" ? "-g" : domain
        return "defaults \(flag)read \(target) \(Self.quoted(key))"
    }

    private static func quoted(_ text: String) -> String {
        text.allSatisfy { $0.isLetter || $0.isNumber || "._-".contains($0) } ? text : "'\(text)'"
    }
}

public extension DefaultApp {
    func isVerified(on system: SystemVersion) -> Bool { verified.contains(system.major) }
}

public extension StoredValue {
    /// In words, with its type: `1 (int)`.
    var described: String { Values.describe(self) }
}
