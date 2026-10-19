//
//  Differ.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//
//
//  Two snapshots, by plain name, old → new. Values are compared as values:
//  a key that is not set and one set to its default are the same setting, and
//  an id only one side recorded (an older catalogue) is listed apart, never
//  counted as drift.
//

import Foundation

public enum Differ {

    /// What differs, and the ids only one side has.
    public static func diff(_ a: Snapshot, _ b: Snapshot, catalogue: Catalogue) -> (changes: [Difference], notCompared: [String]) {
        var changes: [Difference] = []
        var notCompared: [String] = []
        let left = Dictionary(a.settings.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let right = Dictionary(b.settings.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for id in ordered(Array(left.keys) + Array(right.keys), catalogue: catalogue) {
            guard let old = left[id], let new = right[id] else { notCompared.append(id); continue }
            let setting = catalogue.setting(id)
            let x = effective(old, setting), y = effective(new, setting)
            guard !Values.same(x, y) else { continue }
            changes.append(Difference(id: id, label: setting?.label ?? old.label ?? new.label ?? id,
                                      group: setting?.group ?? old.group ?? new.group ?? "",
                                      from: text(x, setting), to: text(y, setting)))
        }
        let leftApps = Dictionary(a.defaultApps.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let rightApps = Dictionary(b.defaultApps.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for id in ordered(Array(leftApps.keys) + Array(rightApps.keys), catalogue: catalogue) {
            guard let old = leftApps[id], let new = rightApps[id] else { notCompared.append(id); continue }
            guard old.app != new.app else { continue }
            changes.append(Difference(id: id, label: catalogue.defaultApp(id)?.label ?? old.label ?? id, group: DefaultApp.group,
                                      from: old.name ?? old.app ?? "none", to: new.name ?? new.app ?? "none"))
        }
        return (changes, notCompared)
    }

    /// The value in force: a key not set means its default.
    static func effective(_ entry: SnapshotSetting, _ setting: Setting?) -> SettingValue? {
        guard let setting else { return entry.value }
        if !entry.isSet { return setting.defaultValue }
        return entry.value.flatMap { Values.coerce($0, to: setting.type) } ?? entry.value
    }

    private static func text(_ value: SettingValue?, _ setting: Setting?) -> String {
        if let setting { return setting.display(value) }
        return value.map(Values.text) ?? "not set"
    }

    /// Catalogue order first, then anything else alphabetically.
    private static func ordered(_ ids: [String], catalogue: Catalogue) -> [String] {
        let unique = Set(ids)
        let known = catalogue.ids.filter(unique.contains)
        return known + unique.subtracting(known).sorted()
    }
}
