//
//  AppTargetKind.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What a default app is the default for: a URL scheme (`mailto`) or a
/// content type (`com.adobe.pdf`).
public enum AppTargetKind: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    case scheme
    case type
}
