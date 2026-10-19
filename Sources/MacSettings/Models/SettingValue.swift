//
//  SettingValue.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A setting's value as a person sets it: on or off, a number, a word.
///
/// In JSON it is the bare value — `true`, `48`, `0.5`, `"bottom"` — so a
/// snapshot reads like a settings file rather than a type dump.
public enum SettingValue: Equatable, Hashable, Sendable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
}
