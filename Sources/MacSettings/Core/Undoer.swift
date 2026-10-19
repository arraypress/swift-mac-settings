//
//  Undoer.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//
//
//  Puts journalled values back exactly — the same type, or the key removed
//  again — but only where the value is still the one that was written. A key
//  someone changed since is theirs now, and is left alone unless forced.
//

import Foundation

public enum Undoer {

    /// Restores a batch (`nil`: the last one not yet undone), newest write first.
    public static func undo(_ target: String?, context: SettingsContext, force: Bool = false,
                            catalogue: Catalogue? = nil) throws(SettingsError) -> [UndoOutcome] {
        var all = try JournalStore.load(context.journal)
        let chosen = try JournalStore.select(all, target: target)
        var outcomes: [UndoOutcome] = []
        for entry in chosen.reversed() {
            let outcome = restore(entry, context: context, force: force, catalogue: catalogue)
            outcomes.append(outcome)
            if outcome.result == .restored, let index = all.firstIndex(where: { $0.id == entry.id }) {
                all[index].restoredAt = Date()
            }
        }
        try JournalStore.save(all, to: context.journal)
        return outcomes
    }

    static func restore(_ entry: JournalEntry, context: SettingsContext, force: Bool, catalogue: Catalogue? = nil) -> UndoOutcome {
        if let place = entry.place, let before = entry.before, let after = entry.after {
            let now = context.store.read(place)
            if now == before { return UndoOutcome(entry: entry, result: .restored, reason: "already as it was") }
            if now != after && !force {
                return UndoOutcome(entry: entry, result: .conflict,
                                   reason: "now \(now.described), not the \(after.described) that was written — left alone (--force restores it anyway)")
            }
            context.store.write(before, to: place)
            let back = context.store.read(place)
            return back == before ? UndoOutcome(entry: entry, result: .restored)
                : UndoOutcome(entry: entry, result: .failed, reason: "reads back as \(back.described)")
        }
        if let control = entry.control, let after = entry.valueAfter {
            let now = ControlRun.read(entry.setting, control: control, catalogue: catalogue, context: context)
            guard let before = entry.valueBefore else {
                return UndoOutcome(entry: entry, result: .failed, reason: "the value before was not readable, so it cannot be put back")
            }
            if Values.same(now, before) { return UndoOutcome(entry: entry, result: .restored, reason: "already as it was") }
            if !Values.same(now, after) && !force {
                return UndoOutcome(entry: entry, result: .conflict,
                                   reason: "now \(now.map(Values.text) ?? "unreadable"), not the \(Values.text(after)) that was set — left alone (--force restores it anyway)")
            }
            let (landed, reason) = ControlRun.set(control, to: before, settingID: entry.setting, catalogue: catalogue, context: context)
            return UndoOutcome(entry: entry, result: landed ? .restored : .failed, reason: reason)
        }
        guard let kind = entry.kind, let target = entry.target, let after = entry.appAfter else {
            return UndoOutcome(entry: entry, result: .failed, reason: "a journal entry this version cannot read")
        }
        let now = context.apps.handler(kind: kind, target: target)
        guard let before = entry.appBefore else {
            return UndoOutcome(entry: entry, result: .failed, reason: "\(target) had no default app before, and macOS cannot unset one")
        }
        if now == before { return UndoOutcome(entry: entry, result: .restored, reason: "already as it was") }
        if now != after && !force {
            return UndoOutcome(entry: entry, result: .conflict, reason: "now \(now ?? "none"), not \(after) — left alone (--force restores it anyway)")
        }
        switch context.apps.setHandler(before, kind: kind, target: target, timeout: context.appTimeout) {
        case .done:
            let back = context.apps.handler(kind: kind, target: target)
            return back == before ? UndoOutcome(entry: entry, result: .restored)
                : UndoOutcome(entry: entry, result: .failed, reason: "\(target) still opens with \(back ?? "nothing")")
        case .pending: return UndoOutcome(entry: entry, result: .pending, reason: "macOS is asking you to confirm it — answer the dialog")
        case .failed(let reason): return UndoOutcome(entry: entry, result: .failed, reason: reason)
        }
    }
}
