//
//  PreferenceScanner.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//
//
//  Every preference key of the current user, as cfprefsd has it — for
//  `learn`. Measured on macOS 27: reading all ~770 domains through
//  CFPreferences takes 0.07–0.17 s, and a change another process makes is
//  visible this way within ~70 ms. The plist files on disk lag (cfprefsd
//  writes them lazily; FSEvents saw a new file only 4.4 s later), so the files
//  are used only to learn which domains exist, never for their contents.
//

import CoreFoundation
import Foundation

public enum PreferenceScanner {

    /// The current user's preferences folder.
    public static var folder: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences")
    }

    /// Every domain with a file in `folder` (and its ByHost folder).
    public static func domains(in folder: URL = folder) -> [(domain: String, host: HostScope)] {
        let manager = FileManager.default
        var found: [(String, HostScope)] = []
        for name in (try? manager.contentsOfDirectory(atPath: folder.path)) ?? [] {
            if let domain = domain(fromFile: name, byHost: false) { found.append((domain, .any)) }
        }
        for name in (try? manager.contentsOfDirectory(atPath: folder.appendingPathComponent("ByHost").path)) ?? [] {
            if let domain = domain(fromFile: name, byHost: true) { found.append((domain, .current)) }
        }
        return found.sorted { ($0.0, $0.1.rawValue) < ($1.0, $1.1.rawValue) }
    }

    /// `com.apple.dock.plist` → `com.apple.dock`; a ByHost file also loses its
    /// host id (`com.apple.screensaver.<UUID>.plist`); `.GlobalPreferences`
    /// is `NSGlobalDomain`.
    static func domain(fromFile name: String, byHost: Bool) -> String? {
        guard name.hasSuffix(".plist") else { return nil }
        var base = String(name.dropLast(6))
        if byHost {
            guard let dot = base.lastIndex(of: ".") else { return nil }
            let host = base[base.index(after: dot)...]
            guard host.count == 36 || (host.count == 12 && host.allSatisfy(\.isHexDigit)) else { return nil }
            base = String(base[..<dot])
        }
        if base == ".GlobalPreferences" { return "NSGlobalDomain" }
        return base.isEmpty || base.hasPrefix(".") ? nil : base
    }

    /// Every key in `domains`, fresh from cfprefsd.
    public static func scan(_ domains: [(domain: String, host: HostScope)]) -> [Place: StoredValue] {
        var values: [Place: StoredValue] = [:]
        for (domain, host) in domains {
            let app = CFPreferenceStore.application(domain)
            let hostRef = host == .current ? kCFPreferencesCurrentHost : kCFPreferencesAnyHost
            CFPreferencesSynchronize(app, kCFPreferencesCurrentUser, hostRef)
            guard let keys = CFPreferencesCopyKeyList(app, kCFPreferencesCurrentUser, hostRef) as? [String] else { continue }
            for key in keys {
                let place = Place(domain: domain, key: key, host: host)
                values[place] = PlistValues.stored(CFPreferencesCopyValue(key as CFString, app, kCFPreferencesCurrentUser, hostRef))
            }
        }
        return values
    }

    /// The keys whose values differ between two scans (added and removed too).
    public static func changes(from old: [Place: StoredValue], to new: [Place: StoredValue]) -> [(place: Place, from: StoredValue, to: StoredValue)] {
        Set(old.keys).union(new.keys).compactMap { place in
            let a = old[place] ?? .absent, b = new[place] ?? .absent
            return a == b ? nil : (place, a, b)
        }.sorted { ($0.place.domain, $0.place.key) < ($1.place.domain, $1.place.key) }
    }
}
