//
//  PaneURL.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

enum PaneURL {

    /// `x-apple.systempreferences:<pane id>`, the URL that opens a System
    /// Settings pane (`open "<url>"`).
    static func url(for pane: String?) -> String? {
        pane.map { "x-apple.systempreferences:" + $0 }
    }
}
