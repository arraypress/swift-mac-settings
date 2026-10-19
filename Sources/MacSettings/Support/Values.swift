//
//  Values.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//
//
//  Values between the three forms they take: what a person types, what a
//  setting means (`SettingValue`), and what the plist holds (`StoredValue`).
//  Pure functions; the catalogue's types decide every conversion.
//

import Foundation

enum Values {

    /// Words a person may type for on and off.
    static let truths: Set<String> = ["true", "yes", "on", "1", "enabled", "enable"]
    static let falsehoods: Set<String> = ["false", "no", "off", "0", "disabled", "disable"]

    /// The word that means "remove the key, so the default is in force".
    static let defaultWord = "default"

    /// `value` as `type`, or `nil` when it is not one: a whole real is an int,
    /// an int is a real, and nothing else crosses over.
    static func coerce(_ value: SettingValue, to type: SettingType) -> SettingValue? {
        switch (type, value) {
        case (.bool, .bool): return value
        case (.int, .int): return value
        case (.int, .double(let d)): return d.rounded() == d && abs(d) < 1e15 ? .int(Int(d)) : nil
        case (.float, .double): return value
        case (.float, .int(let i)): return .double(Double(i))
        case (.string, .string): return value
        default: return nil
        }
    }

    /// Why `value` is not allowed for `setting`, or `nil` when it is.
    static func problem(with value: SettingValue, for setting: Setting) -> String? {
        guard let value = coerce(value, to: setting.type) else { return "is not a \(setting.type.rawValue)" }
        if !setting.choices.isEmpty {
            let allowed = setting.choices.compactMap { coerce($0.value, to: setting.type) }
            if !allowed.contains(where: { same($0, value) }) {
                return "must be one of \(setting.choices.map { "\($0.label) (\(text($0.value)))" }.joined(separator: ", "))"
            }
        }
        if let number = number(value) {
            if let min = setting.min, number < min { return "must be at least \(text(.double(min)))" }
            if let max = setting.max, number > max { return "must be at most \(text(.double(max)))" }
        }
        if case .string(let s) = value, s.isEmpty { return "cannot be empty" }
        return nil
    }

    /// What a person typed, as a value for `setting`: a choice by label or by
    /// value, on/off words for booleans, numbers for numbers. `nil` result
    /// means "default". Throws with the allowed values when it fits nothing.
    static func parse(_ text: String, for setting: Setting) throws(SettingsError) -> SettingValue? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.lowercased() == defaultWord { return nil }
        let lowered = trimmed.lowercased()
        if let choice = setting.choices.first(where: { $0.label.lowercased() == lowered })
            ?? setting.choices.first(where: { self.text($0.value).lowercased() == lowered }) {
            return coerce(choice.value, to: setting.type)
        }
        let value: SettingValue?
        switch setting.type {
        case .bool:
            value = truths.contains(lowered) ? .bool(true) : falsehoods.contains(lowered) ? .bool(false) : nil
        case .int:
            value = Int(trimmed).map(SettingValue.int)
        case .float:
            value = Double(trimmed).flatMap { $0.isFinite ? SettingValue.double($0) : nil }
        case .string:
            value = trimmed.isEmpty ? nil : .string(trimmed)
        }
        guard let value else {
            throw .invalidValue(id: setting.id, reason: "\"\(text)\" is not \(expectation(for: setting))")
        }
        if let reason = problem(with: value, for: setting) {
            throw .invalidValue(id: setting.id, reason: "\(self.text(value)) \(reason)")
        }
        return value
    }

    /// What a setting accepts, in words, for error messages and `get`.
    static func expectation(for setting: Setting) -> String {
        if !setting.choices.isEmpty { return "one of " + setting.choices.map(\.label).joined(separator: ", ") }
        switch setting.type {
        case .bool: return "on or off"
        case .int, .float:
            let kind = setting.type == .int ? "a whole number" : "a number"
            switch (setting.min, setting.max) {
            case let (min?, max?): return "\(kind) from \(text(.double(min))) to \(text(.double(max)))"
            case let (min?, nil): return "\(kind) of at least \(text(.double(min)))"
            case let (nil, max?): return "\(kind) of at most \(text(.double(max)))"
            case (nil, nil): return kind
            }
        case .string: return "some text"
        }
    }

    /// The meaning of what the plist holds, as `setting`'s type; `nil` when it
    /// holds nothing or something that cannot be read as that type.
    static func logical(_ stored: StoredValue, for setting: Setting) -> SettingValue? {
        switch (setting.type, stored) {
        case (_, .absent), (_, .plist): return nil
        case (.bool, .bool(let b)): return .bool(b)
        case (.bool, .int(let i)): return .bool(i != 0)
        case (.bool, .real(let r)): return .bool(r != 0)
        case (.bool, .string(let s)):
            return truths.contains(s.lowercased()) ? .bool(true) : falsehoods.contains(s.lowercased()) ? .bool(false) : nil
        case (.int, .int(let i)): return .int(i)
        case (.int, .real(let r)): return coerce(.double(r), to: .int)
        case (.int, .bool(let b)): return .int(b ? 1 : 0)
        case (.int, .string(let s)): return Int(s).map(SettingValue.int)
        case (.float, .real(let r)): return .double(r)
        case (.float, .int(let i)): return .double(Double(i))
        case (.float, .string(let s)): return Double(s).map(SettingValue.double)
        case (.float, .bool): return nil
        case (.string, .string(let s)): return .string(s)
        case (.string, _): return nil
        }
    }

    /// What to store for `value`: the type System Settings writes.
    static func stored(_ value: SettingValue, for setting: Setting) -> StoredValue {
        let value = coerce(value, to: setting.type) ?? value
        switch value {
        case .bool(let b): return setting.storage == .int ? .int(b ? 1 : 0) : .bool(b)
        case .int(let i): return setting.type == .float ? .real(Double(i)) : .int(i)
        case .double(let d): return .real(d)
        case .string(let s): return .string(s)
        }
    }

    /// Equal as values: reals within a hair, ints and reals across.
    static func same(_ a: SettingValue?, _ b: SettingValue?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (x?, y?):
            if let p = number(x), let q = number(y), !isBool(x), !isBool(y) { return abs(p - q) < 1e-9 }
            return x == y
        default: return false
        }
    }

    /// A value in words: `on`/`off`, a choice's label, a number without a
    /// needless `.0`, text as itself, and `not set` for nothing.
    static func display(_ value: SettingValue?, for setting: Setting) -> String {
        guard let value else { return "not set" }
        if let choice = setting.choices.first(where: { same(coerce($0.value, to: setting.type), value) }) { return choice.label }
        if case .bool(let b) = value { return b ? "on" : "off" }
        return text(value)
    }

    /// A value as text, the way a person would type it back.
    static func text(_ value: SettingValue) -> String {
        switch value {
        case .bool(let b): return b ? "true" : "false"
        case .int(let i): return String(i)
        case .double(let d):
            if d.rounded() == d && abs(d) < 1e15 { return String(Int(d)) }
            return String(d)
        case .string(let s): return s
        }
    }

    /// A stored value in words, for `learn` and journals: `1 (int)`.
    static func describe(_ stored: StoredValue) -> String {
        switch stored {
        case .absent: return "not set"
        case .bool(let b): return "\(b) (bool)"
        case .int(let i): return "\(i) (int)"
        case .real(let r): return "\(r) (real)"
        case .string(let s): return "\"\(s)\" (string)"
        case .plist(let data): return "\(data.count)-byte value (array, dictionary, data or date)"
        }
    }

    private static func number(_ value: SettingValue) -> Double? {
        switch value {
        case .int(let i): return Double(i)
        case .double(let d): return d
        default: return nil
        }
    }

    private static func isBool(_ value: SettingValue) -> Bool {
        if case .bool = value { return true }
        return false
    }
}
