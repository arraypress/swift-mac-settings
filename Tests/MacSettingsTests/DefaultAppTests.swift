//
//  DefaultAppTests.swift
//  MacSettingsTests
//
//  Created by David Sherlock on 2026.
//
//
//  Default apps against a fake LaunchServices: no real handler is changed.
//

import Foundation
import Testing
@testable import MacSettings

struct DefaultAppTests {

    @Test func anAppIsFoundByNameBundleIDOrPath() throws {
        let f = try Fixture()
        let catalogue = f.catalogue([], apps: [browserEntry()])
        for typed in ["Other Browser", "com.example.other", "other browser.app", "/Applications/Other Browser.app"] {
            let item = try Planner.planSet(id: "default-apps.browser", value: typed, catalogue: catalogue, context: f.context())
            #expect(item.app?.after == "com.example.other", "\(typed)")
        }
        #expect(throws: SettingsError.self) {
            try Planner.planSet(id: "default-apps.browser", value: "Nonexistent", catalogue: catalogue, context: f.context())
        }
    }

    @Test func settingTheBrowserCoversEveryTargetAndUndoes() throws {
        let f = try Fixture()
        f.apps.preset("http", "com.example.browser")
        f.apps.preset("https", "com.example.browser")
        let catalogue = f.catalogue([], apps: [browserEntry()])
        let item = try Planner.planSet(id: "default-apps.browser", value: "Other Browser", catalogue: catalogue, context: f.context())
        #expect(f.apps.calls.isEmpty, "the plan changed nothing")
        #expect(try Applier.apply([item], context: f.context()).map(\.result) == [.applied])
        #expect(f.apps.handler(kind: .scheme, target: "https") == "com.example.other")
        #expect(try Undoer.undo(nil, context: f.context()).map(\.result) == [.restored, .restored])
        #expect(f.apps.handler(kind: .scheme, target: "http") == "com.example.browser")
    }

    @Test func aDialogStillOpenIsPendingNotDone() throws {
        let f = try Fixture()
        f.apps.preset("http", "com.example.browser")
        f.apps.answer = .pending
        let catalogue = f.catalogue([], apps: [browserEntry()])
        let item = try Planner.planSet(id: "default-apps.browser", value: "com.example.other", catalogue: catalogue, context: f.context())
        let outcome = try Applier.apply([item], context: f.context())
        #expect(outcome.map(\.result) == [.pending])
    }

    @Test func theSameAppIsUnchanged() throws {
        let f = try Fixture()
        f.apps.preset("http", "com.example.browser")
        f.apps.preset("https", "com.example.browser")
        let item = try Planner.planSet(id: "default-apps.browser", value: "Example Browser",
                                       catalogue: f.catalogue([], apps: [browserEntry()]), context: f.context())
        #expect(item.status == .unchanged)
    }

    @Test func aSnapshotNamingAMissingAppSkipsIt() throws {
        let f = try Fixture()
        let snapshot = Snapshot(settings: [], defaultApps: [SnapshotApp(id: "default-apps.browser", app: "com.example.gone")])
        let plan = Planner.planApply(snapshot, catalogue: f.catalogue([], apps: [browserEntry()]), context: f.context())
        #expect(plan.map(\.skip) == [.appMissing])
    }
}
