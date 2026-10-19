//
//  Groups.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//
//
//  Group names as people type them: `Menu bar`, `menu-bar`, `menubar` and
//  `MENU BAR` are the same group.
//

import Foundation

enum Groups {

    /// `Menu bar` → `menu-bar`.
    static func slug(_ name: String) -> String {
        name.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).joined(separator: "-")
    }

    /// Whether what someone typed names `group`.
    static func matches(_ typed: String, group: String) -> Bool {
        let a = slug(typed), b = slug(group)
        return a == b || a.replacingOccurrences(of: "-", with: "") == b.replacingOccurrences(of: "-", with: "")
    }
}
