// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-mac-settings",
    // macOS only: CFPreferences reaches cfprefsd, and default apps are
    // LaunchServices' through NSWorkspace.
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "MacSettings", targets: ["MacSettings"]),
    ],
    targets: [
        // The catalogue is compiled in (Support/CatalogueData.swift), not a
        // resource bundle: a Homebrew-symlinked binary cannot find
        // Bundle.module, and a tool that cannot find its catalogue must not write.
        .target(name: "MacSettings"),
        .testTarget(name: "MacSettingsTests", dependencies: ["MacSettings"]),
    ]
)

// Swift 7's import rule, today: a file must import every module whose members
// it uses, rather than leaning on another file's imports.
for target in package.targets where target.type != .system && target.type != .binary && target.type != .plugin {
    target.swiftSettings = (target.swiftSettings ?? []) + [.enableUpcomingFeature("MemberImportVisibility")]
}
