//
//  CatalogueTests.swift
//  MacSettingsTests
//
//  Created by David Sherlock on 2026.
//

import Foundation
import Testing
@testable import MacSettings

struct CatalogueTests {

    @Test func builtInCatalogueLoadsAndIsSound() throws {
        let catalogue = try Catalogue.builtIn()
        #expect(catalogue.settings.count >= 100)
        #expect(catalogue.defaultApps.count >= 10)
        #expect(catalogue.problems.isEmpty, "\(catalogue.problems)")
    }

    @Test func everyIDIsUniqueAndStartsWithItsGroup() throws {
        let catalogue = try Catalogue.builtIn()
        #expect(Set(catalogue.ids).count == catalogue.ids.count)
        for setting in catalogue.settings {
            #expect(setting.id.hasPrefix(Groups.slug(setting.group) + "."), "\(setting.id)")
        }
        for app in catalogue.defaultApps { #expect(app.id.hasPrefix("default-apps."), "\(app.id)") }
    }

    @Test func everyEntryWasProbedOnMacOS27() throws {
        let catalogue = try Catalogue.builtIn()
        for setting in catalogue.settings { #expect(setting.verified.contains("27"), "\(setting.id)") }
        for app in catalogue.defaultApps { #expect(app.verified.contains("27"), "\(app.id)") }
    }

    @Test func typesChoicesAndDefaultsAgree() throws {
        for setting in try Catalogue.builtIn().settings {
            for choice in setting.choices { #expect(Values.coerce(choice.value, to: setting.type) != nil, "\(setting.id)") }
            if let value = setting.defaultValue { #expect(Values.problem(with: value, for: setting) == nil, "\(setting.id)") }
        }
    }

    @Test func readOnlyEntriesSayWhyAndWhere() throws {
        let readOnly = try Catalogue.builtIn().settings.filter { !$0.writable }
        #expect(readOnly.count >= 3)
        for setting in readOnly {
            #expect(setting.readOnlyReason?.isEmpty == false, "\(setting.id)")
            #expect(setting.paneURL?.hasPrefix("x-apple.systempreferences:com.apple.") == true, "\(setting.id)")
        }
    }

    @Test func nothingReachesTheOutOfScopeList() throws {
        let catalogue = try Catalogue.builtIn()
        for setting in catalogue.settings {
            for place in setting.places { #expect(!Catalogue.isOutOfScope(place), "\(setting.id)") }
        }
        let names = catalogue.outOfScope.map(\.name).joined(separator: " ")
        for word in ["FileVault", "Integrity", "Gatekeeper", "Firewall", "Passwords", "iCloud"] {
            #expect(names.contains(word), "\(word)")
        }
    }

    @Test func anUnknownKeyIsRefused() {
        let json = #"{"version":1,"probed":"x","outOfScope":[],"settings":[{"id":"dock.x","label":"x","group":"Dock","domain":"com.example.x","key":"k","type":"bool","default":false,"restart":[],"writeable":false,"verified":["27"]}]}"#
        #expect(throws: SettingsError.self) { try Catalogue.decode(Data(json.utf8)) }
    }

    @Test func theCheckCatchesBrokenEntries() throws {
        let f = try Fixture()
        let good = f.setting("good")
        func problems(_ setting: Setting) -> [String] { CatalogueCheck.problems(f.catalogue([setting])) }
        #expect(problems(good).isEmpty, "\(problems(good))")
        #expect(!CatalogueCheck.problems(f.catalogue([good, good])).isEmpty, "duplicate id")
        #expect(!problems(f.setting("unprobed", verified: [])).isEmpty, "never probed")
        #expect(!problems(f.setting("badDefault", defaultValue: .string("yes"))).isEmpty, "default of the wrong type")
        #expect(!problems(f.setting("outOfRange", type: .int, min: 0, max: 3, defaultValue: .int(9))).isEmpty, "default out of range")
        #expect(!problems(f.setting("storage", type: .int, storage: .int, defaultValue: .int(1))).isEmpty, "storage on an int")
        #expect(!problems(f.setting("misgrouped", group: "Dock").with(id: "finder.misgrouped")).isEmpty, "id not under its group")
        #expect(!problems(f.setting("readonly", writable: true).with(writable: false)).isEmpty, "read-only without a reason")
        #expect(!problems(good.with(domain: "/etc/passwd")).isEmpty, "a path, not a domain")
        #expect(!problems(good.with(domain: "com.apple.alf")).isEmpty, "firewall")
        #expect(!problems(good.with(domain: "com.apple.screensaver", key: "askForPassword")).isEmpty, "lock-screen password")
        #expect(!problems(good.with(pane: "javascript:alert(1)")).isEmpty, "not a pane id")
    }
}

extension Setting {
    func with(id: String? = nil, domain: String? = nil, key: String? = nil, writable: Bool? = nil, pane: String? = nil) -> Setting {
        Setting(id: id ?? self.id, label: label, group: group, domain: domain ?? self.domain, key: key ?? self.key, host: host,
                type: type, storage: storage, choices: choices, min: min, max: max, defaultValue: defaultValue,
                restart: restart, pane: pane ?? self.pane, location: location, note: note, mirrors: mirrors,
                writable: writable ?? self.writable, readOnlyReason: readOnlyReason, verified: verified)
    }
}
