//
//  Setting+Codable.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

extension Setting: Codable {

    enum CodingKeys: String, CodingKey, CaseIterable {
        case id, label, group, domain, key, host, type, storage, choices, min, max
        case defaultValue = "default"
        case restart, pane
        case location = "where"
        case note, mirrors, writable, readOnlyReason, verified, control
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let id = (try? c.decode(String.self, forKey: .id)) ?? "?"
        try StrictKeys.check(decoder, allowed: CodingKeys.allCases.map(\.rawValue), in: "setting \(id)")
        self.init(
            id: try c.decode(String.self, forKey: .id),
            label: try c.decode(String.self, forKey: .label),
            group: try c.decode(String.self, forKey: .group),
            domain: try c.decode(String.self, forKey: .domain),
            key: try c.decode(String.self, forKey: .key),
            host: try c.decodeIfPresent(HostScope.self, forKey: .host) ?? .any,
            type: try c.decode(SettingType.self, forKey: .type),
            storage: try c.decodeIfPresent(SettingType.self, forKey: .storage),
            choices: try c.decodeIfPresent([Choice].self, forKey: .choices) ?? [],
            min: try c.decodeIfPresent(Double.self, forKey: .min),
            max: try c.decodeIfPresent(Double.self, forKey: .max),
            // `"default": null` is said on purpose: the default is not known.
            defaultValue: try c.decode(SettingValue?.self, forKey: .defaultValue),
            restart: try c.decode([Restart].self, forKey: .restart),
            pane: try c.decodeIfPresent(String.self, forKey: .pane),
            location: try c.decodeIfPresent(String.self, forKey: .location),
            note: try c.decodeIfPresent(String.self, forKey: .note),
            mirrors: try c.decodeIfPresent([Place].self, forKey: .mirrors) ?? [],
            writable: try c.decodeIfPresent(Bool.self, forKey: .writable) ?? true,
            readOnlyReason: try c.decodeIfPresent(String.self, forKey: .readOnlyReason),
            verified: try c.decode([String].self, forKey: .verified),
            control: try c.decodeIfPresent(Control.self, forKey: .control)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(label, forKey: .label)
        try c.encode(group, forKey: .group)
        try c.encode(domain, forKey: .domain)
        try c.encode(key, forKey: .key)
        if host != .any { try c.encode(host, forKey: .host) }
        try c.encode(type, forKey: .type)
        try c.encodeIfPresent(storage, forKey: .storage)
        if !choices.isEmpty { try c.encode(choices, forKey: .choices) }
        try c.encodeIfPresent(min, forKey: .min)
        try c.encodeIfPresent(max, forKey: .max)
        try c.encode(defaultValue, forKey: .defaultValue)
        try c.encode(restart, forKey: .restart)
        try c.encodeIfPresent(pane, forKey: .pane)
        try c.encodeIfPresent(location, forKey: .location)
        try c.encodeIfPresent(note, forKey: .note)
        if !mirrors.isEmpty { try c.encode(mirrors, forKey: .mirrors) }
        try c.encode(writable, forKey: .writable)
        try c.encodeIfPresent(readOnlyReason, forKey: .readOnlyReason)
        try c.encode(verified, forKey: .verified)
        try c.encodeIfPresent(control, forKey: .control)
    }
}
