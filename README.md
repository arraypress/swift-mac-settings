# Swift Mac Settings

A Mac's settings by plain name — read from cfprefsd, changed only through a plan, journalled so every change can be put back exactly, and snapshotted, diffed and applied as a file.

```swift
import MacSettings

let catalogue = try Catalogue.builtIn()
let context = SettingsContext.live()

// What this Mac is set to.
for reading in Reader.readAll(catalogue, group: "Dock", context: context) where reading.changed {
    print(reading.id, reading.display)            // dock.size 64
}

// Change one: plan (reads only), apply (journal, write, read back), undo.
let item = try Planner.planSet(id: "dock.autohide", value: "on", catalogue: catalogue, context: context)
let outcomes = try Applier.apply([item], context: context)
print(Restarter.needed([item]).map(\.advice))      // ["restart Dock (killall Dock)"]
_ = try Undoer.undo(nil, context: context)

// A whole setup as a file.
let snapshot = Snapshots.take(catalogue, context: context)
try Snapshots.write(snapshot, to: URL(fileURLWithPath: "setup.json"))
let (changes, _) = Differ.diff(snapshot, Snapshots.take(catalogue, context: context), catalogue: catalogue)
let plan = Planner.planApply(snapshot, catalogue: catalogue, context: context)
```

The `settings` CLI is the front end; this is everything it knows.

## Features

- 📋 **The catalogue is data** — strict JSON compiled into the library (not a resource bundle, which a Homebrew-symlinked binary cannot find): `id` (`group.name`), `label`, `group`, `domain`, `key`, `host` (`current` for `-currentHost`/ByHost), `type` (`bool`, `int`, `float`, `string`), `storage` (a boolean kept as 0/1), `choices`, `min`/`max`, `default` (`null` when not known), `restart`, `pane`, `where`, `note`, `mirrors` (keys System Settings writes alongside), `writable` with `readOnlyReason`, and `verified` (macOS versions it was probed on). Unknown keys are refused, and every load checks it: unique ids under their group, choices and defaults of the right type and in range, a reason for every read-only entry, no entry never probed, no domain that is a path, and nothing on the out-of-scope list
- 🚫 **Out of scope, in code** — FileVault, SIP, Gatekeeper, the firewall, passwords and the lock-screen password delay, login-window and account domains, iCloud, privacy grants, Software Update, Time Machine and LaunchServices' own plist are refused by `CatalogueCheck` whatever a catalogue says
- 🔁 **Writes go through cfprefsd** (`CFPreferences`), the same path as `defaults` and System Settings, so nothing edits a plist behind its back and cfprefsd never needs killing
- 🎯 **Exact restore** — `StoredValue` keeps what the plist held, type and all (`1` is not `true` to the app that reads it; a key that was absent is removed again). The journal is written before the write it records, and undo leaves alone any value changed since unless forced
- 🔒 **Profiles respected** — a key set under `/Library/Managed Preferences` (MDM and Screen Time both write there), or forced per CFPreferences, reads as locked and is never written
- 🧭 **Unknown here, skipped** — a setting not verified on this macOS major version is skipped unless allowed; read-only settings carry the `x-apple.systempreferences:` URL of the pane that changes them
- 🗂️ **Default apps** — LaunchServices through NSWorkspace (`setDefaultApplication(at:toOpen:)`, `…toOpenURLsWithScheme:`), never its plist; when macOS asks the person to confirm, the change is `pending`, not done
- 📸 **Snapshots** — JSON, strict about shape (wrong `kind`, unknown key or duplicated id refused), lenient about content: a hand-written setup needs only ids and values. Diffs compare values, so "not set" and "set to the default" are the same, and ids only one side has are listed apart
- 👂 **`PreferenceScanner` + `ChangeTracker`** — every key of every domain through cfprefsd, diffed between reads, with a quiet baseline to leave out keys that change by themselves
- 🧪 **Test seams** — `PreferenceStore`, `AppStore` and `ManagedPreferences(root:)` are injectable; the tests write only to `com.example.settings-tests`

## Measured

Probed on macOS 27.0.1 (26A434), 2026-10-19: all 110 settings read; 105 written with a scratch value through CFPreferences, read back by a separate process (`defaults read`), and put back — every one restored to the same value and type (the original was recorded before each write). Five are read-only by design: appearance and its auto-switch (the key records the choice; the switch is a private call), the region (several keys kept in step), and Stage Manager and greyscale, which were not write-probed because they apply at once on screen. Writing the accessibility domain worked from a terminal with Full Disk Access; without it, that is not measured.

Removing the last key of a domain that had no file leaves an empty plist behind (cfprefsd's doing): the setting is restored, the file is not removed.

Reading every preference domain (~770 on a working Mac) through CFPreferences takes 0.07–0.17 s, and a change another process makes is visible that way within ~70 ms; FSEvents on `~/Library/Preferences` saw a new domain's file only 4.4 s later. That is why `PreferenceScanner` reads cfprefsd and uses the files only to learn which domains exist. (Mutation testing showed the `CFPreferencesSynchronize` before each read is redundant on macOS 27 — `CFPreferencesCopyValue` already sees another process's write — so it stays only as cheap insurance on other versions.)

## Tests

`swift test`: 64, in Swift Testing — the catalogue's own checks, value parsing and conversion, the live store against the real cfprefsd, profiles from fixture plists, set/apply/undo, snapshots and diffs, default apps against a fake LaunchServices, and `learn`'s scanner. Every write goes to one scratch domain, `com.example.settings-tests`, under keys unique to the test, removed afterwards (an empty `com.example.settings-tests.plist` stays behind, as above). Each test was mutation-checked: 78 tests across this and the CLI, each failing under a mutation of the code it covers.

## Credits

Written for this library. [macos-defaults.com](https://macos-defaults.com) was read for three documented Dock defaults; [prefsniff](https://github.com/zcutlip/prefsniff) for the idea of watching preferences while a toggle is flipped. No code was copied.

## Requirements

macOS 14+, Swift 6.2. No dependencies. The catalogue is verified on macOS 27; other versions read everything and write only with `allowUnverified`.

## License

MIT — see LICENSE.
