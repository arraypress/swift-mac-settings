//
//  Applier.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//
//
//  Makes a plan real: each key is checked against the value the plan saw,
//  journalled, written through cfprefsd, and read back. A key that reads back
//  as something else is a failure, not a success with a footnote.
//

import Foundation

public enum Applier {

    /// Applies every `.change` item; the rest come back as they were planned.
    ///
    /// - Throws: only when the journal cannot be written — and then before
    ///   anything is: a change that cannot be undone is not made.
    public static func apply(_ plan: [PlanItem], context: SettingsContext,
                             batch: String = JournalStore.newBatch()) throws(SettingsError) -> [Outcome] {
        var outcomes: [Outcome] = []
        for item in plan {
            switch item.status {
            case .unchanged: outcomes.append(Outcome(item: item, result: .unchanged))
            case .skipped: outcomes.append(Outcome(item: item, result: .skipped, reason: item.reason))
            case .change:
                if let app = item.app {
                    outcomes.append(try applyApp(item, app, context: context, batch: batch))
                } else {
                    outcomes.append(try applyWrites(item, context: context, batch: batch))
                }
            }
        }
        return outcomes
    }

    private static func applyWrites(_ item: PlanItem, context: SettingsContext, batch: String) throws(SettingsError) -> Outcome {
        // Nothing may have moved since the plan read it.
        for write in item.writes where context.store.read(write.place) != write.before {
            return Outcome(item: item, result: .skipped, reason: "\(write.place.domain) \(write.place.key) changed since the plan was made")
        }
        let now = Date()
        let entries = item.writes.enumerated().map { index, write in
            JournalEntry(id: "\(batch)-\(item.id)-\(index)", batch: batch, setting: item.id, at: now,
                         place: write.place, before: write.before, after: write.after)
        }
        try JournalStore.append(entries, to: context.journal)
        var problems: [String] = []
        for write in item.writes {
            if !context.store.write(write.after, to: write.place) { problems.append("cfprefsd refused \(write.place.key)") }
            let back = context.store.read(write.place)
            if back != write.after { problems.append("\(write.place.key) reads back as \(back.described), not \(write.after.described)") }
        }
        return Outcome(item: item, result: problems.isEmpty ? .applied : .failed,
                       reason: problems.isEmpty ? nil : problems.joined(separator: "; "), batch: batch)
    }

    private static func applyApp(_ item: PlanItem, _ app: PlannedApp, context: SettingsContext, batch: String) throws(SettingsError) -> Outcome {
        let now = Date()
        let entries = zip(app.targets, app.before).map { target, before in
            JournalEntry(id: "\(batch)-\(item.id)-\(target)", batch: batch, setting: item.id, at: now, kind: app.kind,
                         target: target, appBefore: before, appAfter: app.after)
        }
        try JournalStore.append(entries, to: context.journal)
        var pending = false
        var problems: [String] = []
        for target in app.targets {
            switch context.apps.setHandler(app.after, kind: app.kind, target: target, timeout: context.appTimeout) {
            case .done:
                let back = context.apps.handler(kind: app.kind, target: target)
                if back != app.after { problems.append("\(target) still opens with \(back ?? "nothing")") }
            case .pending: pending = true
            case .failed(let reason): problems.append("\(target): \(reason)")
            }
        }
        if !problems.isEmpty { return Outcome(item: item, result: .failed, reason: problems.joined(separator: "; "), batch: batch) }
        if pending {
            return Outcome(item: item, result: .pending, reason: "macOS is asking you to confirm it — answer the dialog", batch: batch)
        }
        return Outcome(item: item, result: .applied, batch: batch)
    }
}
