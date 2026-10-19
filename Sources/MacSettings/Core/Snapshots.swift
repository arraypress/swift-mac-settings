//
//  Snapshots.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//
//
//  A Mac's setup as a file. JSON, not YAML: the values are typed (true, 48,
//  0.5, "bottom") and JSON keeps those types without a parser that reads a
//  bare `no` as false; Foundation reads and writes it with no dependency; and
//  every fleet tool and `--field` already speak it.
//

import Foundation

public enum Snapshots {

    /// Every catalogued value now: the value in force, and whether it is set.
    public static func take(_ catalogue: Catalogue, context: SettingsContext, at date: Date = Date()) -> Snapshot {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        var settings: [SnapshotSetting] = []
        var apps: [SnapshotApp] = []
        for setting in catalogue.settings {
            let reading = Reader.read(setting, context: context)
            settings.append(SnapshotSetting(id: setting.id, label: setting.label, group: setting.group, value: reading.value,
                                            set: reading.set, locked: reading.locked ? true : nil))
        }
        for app in catalogue.defaultApps {
            let bundleID = app.targets.first.flatMap { context.apps.handler(kind: app.kind, target: $0) }
            apps.append(SnapshotApp(id: app.id, label: app.label, app: bundleID,
                                    name: bundleID.flatMap { context.apps.app(bundleID: $0)?.name }))
        }
        return Snapshot(macOS: context.system.version, build: context.system.build, takenAt: formatter.string(from: date),
                        catalogue: catalogue.version, settings: settings, defaultApps: apps)
    }

    /// Reads a snapshot file strictly: the wrong `kind`, an unknown key or a
    /// duplicated id is refused with the reason.
    public static func read(_ url: URL) throws(SettingsError) -> Snapshot {
        let data: Data
        do { data = try Data(contentsOf: url) } catch {
            throw .invalidSnapshot("cannot read \(url.path): \(error.localizedDescription)")
        }
        return try decode(data)
    }

    public static func decode(_ data: Data) throws(SettingsError) -> Snapshot {
        let snapshot: Snapshot
        do {
            snapshot = try JSONDecoder().decode(Snapshot.self, from: data)
        } catch let DecodingError.dataCorrupted(context) {
            throw .invalidSnapshot(context.debugDescription + (context.underlyingError.map { " (\($0.localizedDescription))" } ?? ""))
        } catch let DecodingError.keyNotFound(key, _) {
            throw .invalidSnapshot("missing \(key.stringValue)")
        } catch {
            throw .invalidSnapshot(String(describing: error))
        }
        guard snapshot.kind == Snapshot.kindName else {
            throw .invalidSnapshot("kind is \(snapshot.kind), not \(Snapshot.kindName)")
        }
        let ids = snapshot.settings.map(\.id) + snapshot.defaultApps.map(\.id)
        let duplicates = Dictionary(grouping: ids, by: { $0 }).filter { $0.value.count > 1 }.keys.sorted()
        guard duplicates.isEmpty else { throw .invalidSnapshot("listed twice: \(duplicates.joined(separator: ", "))") }
        return snapshot
    }

    /// Pretty, key-sorted JSON: stable enough to keep in git and diff by eye.
    public static func encode(_ snapshot: Snapshot) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(snapshot)) ?? Data()
    }

    public static func write(_ snapshot: Snapshot, to url: URL) throws(SettingsError) {
        do {
            try encode(snapshot).write(to: url, options: .atomic)
        } catch {
            throw .invalidSnapshot("cannot write \(url.path): \(error.localizedDescription)")
        }
    }
}
