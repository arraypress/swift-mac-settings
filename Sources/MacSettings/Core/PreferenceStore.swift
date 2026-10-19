//
//  PreferenceStore.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//
//
//  Reading and writing preference keys. The live store goes through
//  CFPreferences, which is cfprefsd: the same path `defaults` and System
//  Settings use, so a running app that watches its defaults sees the change
//  and nothing ever edits a plist file behind cfprefsd's back.
//

import CoreFoundation
import Foundation

/// Where preference values come from and go to.
public protocol PreferenceStore: Sendable {
    /// What `place` holds now, exactly.
    func read(_ place: Place) -> StoredValue
    /// Writes `value` (`.absent` removes the key) and flushes it; false when
    /// cfprefsd refused the write.
    @discardableResult func write(_ value: StoredValue, to place: Place) -> Bool
    /// Whether a configuration profile forces the key.
    func isForced(_ place: Place) -> Bool
}

/// The current user's real preferences, through CFPreferences.
public struct CFPreferenceStore: PreferenceStore {

    public init() {}

    public func read(_ place: Place) -> StoredValue {
        let (app, host) = Self.refs(place)
        // Synchronize first: another process (System Settings, `defaults`)
        // may have changed it since this process last looked.
        CFPreferencesSynchronize(app, kCFPreferencesCurrentUser, host)
        return PlistValues.stored(CFPreferencesCopyValue(place.key as CFString, app, kCFPreferencesCurrentUser, host))
    }

    @discardableResult
    public func write(_ value: StoredValue, to place: Place) -> Bool {
        let (app, host) = Self.refs(place)
        CFPreferencesSetValue(place.key as CFString, PlistValues.object(value), app, kCFPreferencesCurrentUser, host)
        return CFPreferencesSynchronize(app, kCFPreferencesCurrentUser, host)
    }

    public func isForced(_ place: Place) -> Bool {
        CFPreferencesAppValueIsForced(place.key as CFString, Self.refs(place).app)
    }

    /// The CFPreferences application and host for a place.
    static func refs(_ place: Place) -> (app: CFString, host: CFString) {
        (Self.application(place.domain), place.host == .current ? kCFPreferencesCurrentHost : kCFPreferencesAnyHost)
    }

    /// `NSGlobalDomain` is CFPreferences' "any application".
    static func application(_ domain: String) -> CFString {
        domain == "NSGlobalDomain" ? kCFPreferencesAnyApplication : domain as CFString
    }
}
