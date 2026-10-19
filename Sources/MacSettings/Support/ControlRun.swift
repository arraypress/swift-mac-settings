//
//  ControlRun.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//
//  One helper-shortcut write, believed only when the setting reads back as
//  asked. Shared by apply and undo.
//

import AppleShortcuts
import Foundation

enum ControlRun {

    /// The setting's value now, from its reader or its preference key.
    static func read(_ id: String, control: Control, catalogue: Catalogue?, context: SettingsContext) -> SettingValue? {
        guard let setting = (catalogue ?? (try? Catalogue.builtIn()))?.setting(id) else {
            return control.probe.flatMap { if case .value(let value) = context.controls.read(probe: $0) { value } else { nil } }
        }
        return Reader.read(setting, context: context).value
    }

    /// Runs the helper and reads back. Returns whether it landed, and why not.
    static func set(_ control: Control, to value: SettingValue, settingID: String, catalogue: Catalogue?,
                    context: SettingsContext) -> (Bool, String?) {
        let reader = { ControlRun.read($0, control: control, catalogue: catalogue, context: context) }
        let setting = (catalogue ?? (try? Catalogue.builtIn()))?.setting(settingID)
        func words(_ value: SettingValue?) -> String {
            guard let value else { return "unreadable" }
            return setting?.display(value) ?? Values.text(value)
        }
        var failure: String?
        var timedOut = false
        guard let helper = control.helper, let input = ControlInput.input(control, value: value) else {
            return (false, "\(control.helper ?? "no helper") has no branch for \(words(value)); nothing ran")
        }
        do {
            try context.controls.run(helper: helper, input: input)
        } catch let error as HelperError {
            // Refused before running: nothing happened.
            return (false, error.localizedDescription + (error.remedy.map { " — \($0)" } ?? ""))
        } catch {
            if case .timedOut = error as? ShortcutsError { timedOut = true }
            failure = "the shortcut failed: \((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)"
        }
        var seen: SettingValue?
        for attempt in 0..<context.controlAttempts {
            seen = reader(settingID)
            if Values.same(seen, value) { return (true, nil) }
            if failure != nil, !timedOut, attempt >= 2 { break }
            Thread.sleep(forTimeInterval: context.controlInterval)
        }
        return (false, [failure, "reads back as \(words(seen)), not \(words(value))"]
            .compactMap { $0 }.joined(separator: "; "))
    }
}
