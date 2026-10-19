//
//  Control.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// How a setting that only Shortcuts can change is changed, and where it is
/// read from when it has no preference key.
///
/// ```json
/// "control": {"helper": "settings.system", "keys": {"on": "night-shift-on", "off": "night-shift-off"}, "probe": "night-shift"}
/// "control": {"helper": "settings.system", "field": "brightness", "probe": "brightness"}
/// ```
///
/// `keys` names, for each value (`on`/`off` for a switch, the stored value for
/// a choice), the input key the helper's If tests for: MEASURED, the Mac
/// editor keeps only "has any value" Ifs, so a helper takes one key per
/// branch and each branch's action has a fixed value. `field` passes the
/// value itself — for a number.
public struct Control: Codable, Hashable, Sendable {
    /// The helper shortcut's id; `nil` for a setting that is only read here.
    public let helper: String?
    /// Value → input key, for a switch or a choice.
    public let keys: [String: String]
    /// The input field a number goes in, when `keys` is empty.
    public let field: String?
    /// The OS reader the value comes from; `nil`: the preference key.
    public let probe: String?

    public init(helper: String?, keys: [String: String] = [:], field: String? = nil, probe: String? = nil) {
        self.helper = helper
        self.keys = keys
        self.field = field
        self.probe = probe
    }

    enum CodingKeys: String, CodingKey, CaseIterable { case helper, keys, field, probe }

    public init(from decoder: any Decoder) throws {
        try StrictKeys.check(decoder, allowed: CodingKeys.allCases.map(\.rawValue), in: "a control")
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(helper: try c.decodeIfPresent(String.self, forKey: .helper), keys: try c.decodeIfPresent([String: String].self, forKey: .keys) ?? [:],
                  field: try c.decodeIfPresent(String.self, forKey: .field), probe: try c.decodeIfPresent(String.self, forKey: .probe))
    }
}

/// A change made through a helper shortcut: the value before and after.
public struct PlannedControl: Codable, Equatable, Sendable {
    public let control: Control
    public let before: SettingValue?
    public let after: SettingValue

    public init(control: Control, before: SettingValue?, after: SettingValue) {
        self.control = control
        self.before = before
        self.after = after
    }
}
