//
//  LoginItems.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//
//
//  Login items as System Events lists them: the apps in System Settings ›
//  General › Login Items › "Open at Login". Helpers apps register for
//  themselves (SMAppService) and launch agents are not here — `diskmaid
//  startup` shows those, and is where any of them are removed.
//

import Foundation

public enum LoginItems {

    /// The AppleScript: one line per item, name, path and hidden flag
    /// separated by tabs, so no list syntax has to be parsed.
    public static let script = """
        set out to ""
        tell application "System Events"
            repeat with anItem in every login item
                set out to out & (name of anItem) & tab & (path of anItem) & tab & (hidden of anItem as text) & linefeed
            end repeat
        end tell
        return out
        """

    /// The script's output as items; lines that are not three fields are skipped.
    public static func parse(_ text: String) -> [LoginItem] {
        text.split(whereSeparator: \.isNewline).compactMap { line in
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard fields.count == 3, !fields[0].isEmpty else { return nil }
            return LoginItem(name: fields[0], path: fields[1], hidden: fields[2].lowercased() == "true")
        }
    }
}
