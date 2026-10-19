//
//  Planner.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//
//
//  What a `set` or an `apply` WOULD change, worked out without changing
//  anything: every key is read, nothing is written. The plan carries each
//  key's exact value before, so the act that follows can check nothing moved
//  in between, and the journal can put it back.
//

import Foundation

public enum Planner {

    /// The plan for `settings set <id> <value>`. A setting that cannot be
    /// written — read-only, locked, not verified here, a bad value — throws,
    /// with where to change it instead.
    public static func planSet(id: String, value text: String, catalogue: Catalogue,
                               context: SettingsContext) throws(SettingsError) -> PlanItem {
        if let app = catalogue.defaultApp(id) {
            let bundleID = try resolveApp(text, for: app, context: context)
            return try refuseSkipped(plan(app, bundleID: bundleID, context: context), context: context)
        }
        guard let setting = catalogue.setting(id) else {
            try catalogue.requireID(id)
            throw .unknownSetting(id, suggestions: [])
        }
        let target = try setting.parse(text)
        return try refuseSkipped(plan(setting, to: target, context: context), context: context)
    }

    /// The plan for `settings apply <snapshot>`: every entry, each changed,
    /// unchanged or skipped with the reason. Never throws for one bad entry.
    public static func planApply(_ snapshot: Snapshot, catalogue: Catalogue, context: SettingsContext) -> [PlanItem] {
        var items: [PlanItem] = []
        for entry in snapshot.settings {
            guard let setting = catalogue.setting(entry.id) else {
                items.append(PlanItem(id: entry.id, label: entry.label ?? entry.id, status: .skipped, skip: .unknown,
                                      reason: "this version of the catalogue has no \(entry.id)", from: "?", to: "?"))
                continue
            }
            guard entry.isSet else {
                items.append(plan(setting, to: nil, context: context))
                continue
            }
            guard let value = entry.value else {
                items.append(skipped(setting, .invalidValue, "set without a value", to: "?", context: context))
                continue
            }
            if let reason = Values.problem(with: value, for: setting) {
                items.append(skipped(setting, .invalidValue, "\(Values.text(value)) \(reason)", to: Values.text(value), context: context))
                continue
            }
            items.append(plan(setting, to: Values.coerce(value, to: setting.type), context: context))
        }
        for entry in snapshot.defaultApps {
            guard let app = catalogue.defaultApp(entry.id) else {
                items.append(PlanItem(id: entry.id, label: entry.label ?? entry.id, status: .skipped, skip: .unknown,
                                      reason: "this version of the catalogue has no \(entry.id)", from: "?", to: entry.name ?? entry.app ?? "?"))
                continue
            }
            guard let bundleID = entry.app else {
                items.append(PlanItem(id: app.id, label: app.label, status: .unchanged, from: "?", to: "none recorded"))
                continue
            }
            items.append(plan(app, bundleID: bundleID, context: context))
        }
        return items
    }

    /// One setting to `target` (`nil`: remove the key, so the default applies).
    static func plan(_ setting: Setting, to target: SettingValue?, context: SettingsContext) -> PlanItem {
        let current = Reader.read(setting, context: context)
        let toText = target.map { setting.display($0) } ?? "not set" + (setting.defaultValue.map { " (default: \(setting.display($0)))" } ?? "")
        if !setting.isVerified(on: context.system) && !context.allowUnverified {
            return skipped(setting, .unverified,
                           "not verified on macOS \(context.system.major) (verified: \(setting.verified.joined(separator: ", "))); --unverified to try",
                           to: toText, context: context)
        }
        if !setting.writable {
            return skipped(setting, .notWritable, setting.readOnlyReason ?? "read-only", to: toText, context: context)
        }
        if current.locked {
            return skipped(setting, .locked, "set by a configuration profile (MDM or Screen Time)", to: toText, context: context)
        }
        if let control = setting.control, control.helper != nil { return plan(setting, control: control, to: target, current: current, context: context) }
        let after: StoredValue = target.map { Values.stored($0, for: setting) } ?? .absent
        let writes = setting.places.map { PlannedWrite(place: $0, before: context.store.read($0), after: after) }
        let unchanged: Bool
        if target == nil {
            unchanged = writes.allSatisfy { $0.before == .absent }
        } else {
            unchanged = writes.allSatisfy { write in
                let now = write.before == .absent ? setting.defaultValue : Values.logical(write.before, for: setting)
                return Values.same(now, target)
            }
        }
        return PlanItem(id: setting.id, label: setting.label, status: unchanged ? .unchanged : .change,
                        from: current.display, to: toText, writes: unchanged ? [] : writes, restart: setting.restart)
    }

    /// A setting only a helper shortcut can change. Refused when this Mac
    /// cannot read it back — a write nobody can check is not made.
    static func plan(_ setting: Setting, control: Control, to target: SettingValue?, current: Reading,
                     context: SettingsContext) -> PlanItem {
        guard let wanted = target ?? setting.defaultValue else {
            return skipped(setting, .invalidValue, "has no known default for Shortcuts to set", to: "default", context: context)
        }
        let toText = setting.display(wanted)
        guard let before = current.value else {
            return skipped(setting, .notWritable, "cannot be read back on this Mac (\(current.unreadable ?? "no value")), so it is not written",
                           to: toText, context: context)
        }
        if Values.same(before, wanted) {
            return PlanItem(id: setting.id, label: setting.label, status: .unchanged, from: current.display, to: toText, restart: setting.restart)
        }
        return PlanItem(id: setting.id, label: setting.label, status: .change, from: current.display, to: toText, restart: setting.restart,
                        control: PlannedControl(control: control, before: before, after: wanted))
    }

    /// One default app to `bundleID`.
    static func plan(_ app: DefaultApp, bundleID: String, context: SettingsContext) -> PlanItem {
        let now = Reader.read(app, context: context)
        guard let chosen = context.apps.app(bundleID: bundleID) else {
            return PlanItem(id: app.id, label: app.label, status: .skipped, skip: .appMissing,
                            reason: "\(bundleID) is not installed on this Mac", from: now.display, to: bundleID)
        }
        if !app.isVerified(on: context.system) && !context.allowUnverified {
            return PlanItem(id: app.id, label: app.label, status: .skipped, skip: .unverified,
                            reason: "not verified on macOS \(context.system.major); --unverified to try",
                            from: now.display, to: chosen.name)
        }
        let before = app.targets.map { context.apps.handler(kind: app.kind, target: $0) }
        let unchanged = before.allSatisfy { $0 == bundleID }
        return PlanItem(id: app.id, label: app.label, status: unchanged ? .unchanged : .change, from: now.display, to: chosen.name,
                        app: unchanged ? nil : PlannedApp(kind: app.kind, targets: app.targets, before: before,
                                                           after: bundleID, consent: app.consent))
    }

    /// A bundle id, an app name or a .app path, as an installed app that can
    /// open what `app` covers.
    static func resolveApp(_ text: String, for app: DefaultApp, context: SettingsContext) throws(SettingsError) -> String {
        let typed = text.trimmingCharacters(in: .whitespaces)
        let candidates = app.targets.flatMap { context.apps.candidates(kind: app.kind, target: $0) }
        let lowered = typed.lowercased()
        let bare = lowered.hasSuffix(".app") ? String(lowered.dropLast(4)) : lowered
        if let match = candidates.first(where: { $0.bundleID.lowercased() == lowered })
            ?? candidates.first(where: { $0.name.lowercased() == bare })
            ?? candidates.first(where: { $0.path.lowercased() == lowered || ($0.path as NSString).lastPathComponent.lowercased() == lowered }) {
            return match.bundleID
        }
        if let installed = context.apps.app(bundleID: typed) { return installed.bundleID }
        throw .appNotFound(typed, forID: app.id)
    }

    private static func skipped(_ setting: Setting, _ kind: SkipKind, _ reason: String, to: String,
                                context: SettingsContext) -> PlanItem {
        let from = Reader.read(setting, context: context).display
        return PlanItem(id: setting.id, label: setting.label, status: .skipped, skip: kind, reason: reason,
                        from: from, to: to, restart: setting.restart, paneURL: setting.paneURL)
    }

    /// `set` refuses what `apply` would only skip.
    private static func refuseSkipped(_ item: PlanItem, context: SettingsContext) throws(SettingsError) -> PlanItem {
        guard item.status == .skipped, let skip = item.skip else { return item }
        let reason = item.reason ?? skip.rawValue
        switch skip {
        case .notWritable: throw .notWritable(id: item.id, reason: reason, paneURL: item.paneURL)
        case .locked: throw .locked(id: item.id, paneURL: item.paneURL)
        case .unverified: throw .unverified(id: item.id, macOS: context.system.major)
        case .appMissing: throw .appNotFound(item.to, forID: item.id)
        case .invalidValue, .unknown: throw .invalidValue(id: item.id, reason: reason)
        }
    }
}
