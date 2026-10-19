//
//  StoredValue.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Exactly what a preferences key holds, type and all, so it can be put back
/// exactly: an integer 1 is not the boolean true to the app that reads it.
///
/// Anything that is not a scalar (an array, a dictionary, data, a date) is
/// kept whole as a binary property list.
public enum StoredValue: Equatable, Hashable, Sendable {
    /// The key is not set: the app's own default is in force.
    case absent
    case bool(Bool)
    case int(Int)
    case real(Double)
    case string(String)
    /// Any other property-list value, as a binary plist of `{"v": value}`.
    case plist(Data)
}
