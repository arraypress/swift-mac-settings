//
//  Reader.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//
//
//  Settings as they are now, by plain name.
//

import Foundation

public enum Reader {

    /// Every setting and default app, optionally one group's.
    public static func readAll(_ catalogue: Catalogue, group: String? = nil, context: SettingsContext) -> [Reading] {
        let settings = catalogue.settings.filter { group == nil || $0.group == group }
        let apps = group == nil || group == DefaultApp.group ? catalogue.defaultApps : []
        return settings.map { read($0, context: context) } + apps.map { read($0, context: context) }
    }

    /// The reading for any id.
    public static func read(id: String, in catalogue: Catalogue, context: SettingsContext) throws(SettingsError) -> Reading {
        if let setting = catalogue.setting(id) { return read(setting, context: context) }
        if let app = catalogue.defaultApp(id) { return read(app, context: context) }
        try catalogue.requireID(id)
        throw .unknownSetting(id, suggestions: [])
    }

    /// One setting: the stored value, or the default when nothing is stored.
    public static func read(_ setting: Setting, context: SettingsContext) -> Reading {
        if let probe = setting.control?.probe { return read(setting, probe: probe, context: context) }
        let stored = context.store.read(setting.place)
        let isSet = stored != .absent
        let logical = Values.logical(stored, for: setting)
        let value = isSet ? logical : setting.defaultValue
        let unreadable = isSet && logical == nil ? stored.described : nil
        let changed = isSet && (setting.defaultValue == nil || !Values.same(logical, setting.defaultValue))
        let locked = setting.places.contains { context.managed.isManaged($0) || context.store.isForced($0) }
        return Reading(id: setting.id, label: setting.label, group: setting.group, value: value,
                       display: unreadable.map { "unreadable: \($0)" } ?? setting.display(value), set: isSet,
                       changed: changed, locked: locked, writable: setting.writable,
                       verified: setting.isVerified(on: context.system), unreadable: unreadable)
    }

    /// A setting with no preference key: the OS reader's answer.
    static func read(_ setting: Setting, probe: String, context: SettingsContext) -> Reading {
        let verified = setting.isVerified(on: context.system)
        switch context.controls.read(probe: probe) {
        case .value(let value):
            let changed = setting.defaultValue.map { !Values.same(value, $0) } ?? true
            return Reading(id: setting.id, label: setting.label, group: setting.group, value: value, display: setting.display(value),
                           set: true, changed: changed, locked: false, writable: setting.writable, verified: verified)
        case .unavailable(let reason):
            return Reading(id: setting.id, label: setting.label, group: setting.group, value: nil, display: "unavailable: \(reason)",
                           set: false, changed: false, locked: false, writable: setting.writable, verified: verified, unreadable: reason)
        }
    }

    /// One default app: the app that opens its first target (all of them, when they differ).
    public static func read(_ app: DefaultApp, context: SettingsContext) -> Reading {
        let handlers = app.targets.map { context.apps.handler(kind: app.kind, target: $0) }
        let first = handlers.first ?? nil
        func name(_ id: String?) -> String {
            guard let id else { return "none" }
            return context.apps.app(bundleID: id)?.name ?? id
        }
        let display: String
        if Set(handlers).count > 1 {
            display = zip(app.targets, handlers).map { "\(name($1)) (\($0))" }.joined(separator: ", ")
        } else {
            display = name(first)
        }
        let changed = first != nil && app.defaultApp != nil && handlers.contains { $0 != app.defaultApp }
        return Reading(id: app.id, label: app.label, group: DefaultApp.group, value: first.map(SettingValue.string),
                       display: display, set: first != nil, changed: changed, locked: false, writable: true,
                       verified: app.isVerified(on: context.system))
    }
}
