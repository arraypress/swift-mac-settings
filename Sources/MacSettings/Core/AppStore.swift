//
//  AppStore.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//
//
//  Default apps: LaunchServices, through NSWorkspace (macOS 12+). The older
//  LSSetDefaultRoleHandlerForContentType and LSSetDefaultHandlerForURLScheme
//  are deprecated; NSWorkspace's calls are the supported ones, and the SDK's
//  own header says some types and schemes "require user consent" — macOS
//  shows its dialog and calls back only once the person has answered.
//

import AppKit
import Foundation
import UniformTypeIdentifiers

/// An installed app that can be a default.
public struct AppChoice: Codable, Equatable, Hashable, Sendable {
    public let bundleID: String
    public let name: String
    public let path: String

    public init(bundleID: String, name: String, path: String) {
        self.bundleID = bundleID
        self.name = name
        self.path = path
    }
}

/// What happened to a default-app change.
public enum AppWrite: Equatable, Sendable {
    case done
    /// macOS is waiting for the person to confirm in a dialog.
    case pending
    case failed(String)
}

/// Where default apps are read and changed.
public protocol AppStore: Sendable {
    /// The bundle id of the app that opens `target` now.
    func handler(kind: AppTargetKind, target: String) -> String?
    /// Every installed app that can open `target`, best first.
    func candidates(kind: AppTargetKind, target: String) -> [AppChoice]
    /// The installed app with this bundle id.
    func app(bundleID: String) -> AppChoice?
    /// Makes `bundleID` the default for `target`, waiting up to `timeout`
    /// seconds for macOS (and the person, when it asks) to answer.
    func setHandler(_ bundleID: String, kind: AppTargetKind, target: String, timeout: Double) -> AppWrite
}

/// LaunchServices on this Mac.
public struct WorkspaceAppStore: AppStore {

    public init() {}

    public func handler(kind: AppTargetKind, target: String) -> String? {
        url(kind: kind, target: target).flatMap { Bundle(url: $0)?.bundleIdentifier }
    }

    public func candidates(kind: AppTargetKind, target: String) -> [AppChoice] {
        let workspace = NSWorkspace.shared
        let urls: [URL]
        switch kind {
        case .type: urls = UTType(target).map { workspace.urlsForApplications(toOpen: $0) } ?? []
        case .scheme: urls = URL(string: target + ":x").map { workspace.urlsForApplications(toOpen: $0) } ?? []
        }
        var seen = Set<String>()
        return urls.compactMap(Self.choice).filter { seen.insert($0.bundleID).inserted }
    }

    public func app(bundleID: String) -> AppChoice? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID).flatMap(Self.choice)
    }

    public func setHandler(_ bundleID: String, kind: AppTargetKind, target: String, timeout: Double) -> AppWrite {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return .failed("\(bundleID) is not installed")
        }
        let box = AnswerBox()
        let done = DispatchSemaphore(value: 0)
        let finish: @Sendable (Error?) -> Void = { error in
            box.set(error.map { .failed($0.localizedDescription) } ?? .done)
            done.signal()
        }
        switch kind {
        case .type:
            guard let type = UTType(target) else { return .failed("\(target) is not a content type macOS knows") }
            NSWorkspace.shared.setDefaultApplication(at: appURL, toOpen: type, completion: finish)
        case .scheme:
            NSWorkspace.shared.setDefaultApplication(at: appURL, toOpenURLsWithScheme: target, completion: finish)
        }
        guard done.wait(timeout: .now() + timeout) == .success else { return .pending }
        return box.value ?? .failed("no answer")
    }

    private func url(kind: AppTargetKind, target: String) -> URL? {
        switch kind {
        case .type: UTType(target).flatMap { NSWorkspace.shared.urlForApplication(toOpen: $0) }
        case .scheme: URL(string: target + ":x").flatMap { NSWorkspace.shared.urlForApplication(toOpen: $0) }
        }
    }

    private static func choice(_ url: URL) -> AppChoice? {
        guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { return nil }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        return AppChoice(bundleID: id, name: name, path: url.path)
    }
}

/// The completion handler's answer, handed across threads.
private final class AnswerBox: @unchecked Sendable {
    private let lock = NSLock()
    private var answer: AppWrite?
    func set(_ value: AppWrite) { lock.lock(); answer = value; lock.unlock() }
    var value: AppWrite? { lock.lock(); defer { lock.unlock() }; return answer }
}
