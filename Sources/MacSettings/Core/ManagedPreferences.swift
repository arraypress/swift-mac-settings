//
//  ManagedPreferences.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//
//
//  What a configuration profile sets. macOS writes managed values to
//  /Library/Managed Preferences — `<user>/<domain>.plist` for the user,
//  `<domain>.plist` for the computer — for MDM profiles and Screen Time
//  alike. A key there is locked: writing the user's copy changes nothing.
//

import Foundation

/// The managed-preferences folder, read only.
public struct ManagedPreferences: Sendable {

    public let root: URL
    public let user: String

    public init(root: URL = URL(fileURLWithPath: "/Library/Managed Preferences"), user: String = NSUserName()) {
        self.root = root
        self.user = user
    }

    /// Whether a profile sets `place`'s key, for this user or the computer.
    public func isManaged(_ place: Place) -> Bool {
        let file = place.domain == "NSGlobalDomain" ? ".GlobalPreferences" : place.domain
        let candidates = [root.appendingPathComponent(user).appendingPathComponent(file + ".plist"),
                          root.appendingPathComponent(file + ".plist")]
        return candidates.contains { url in
            guard let data = try? Data(contentsOf: url),
                  let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
            else { return false }
            return plist[place.key] != nil
        }
    }
}
