//
//  Restarter.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//
//
//  Restarting what a change needs. Only processes launchd brings straight
//  back (Dock, Finder, SystemUIServer, ControlCenter) are ever restarted, and
//  only when asked; apps and log-outs are said, never done.
//

import Foundation

public enum Restarter {

    /// What the applied changes need, in a stable order, each once.
    public static func needed(_ items: [PlanItem]) -> [Restart] {
        let wanted = Set(items.flatMap(\.restart))
        return Restart.allCases.filter(wanted.contains)
    }

    /// `killall <process>` for each restartable one; whether each worked.
    public static func restart(_ restarts: [Restart],
                               killall: URL = URL(fileURLWithPath: "/usr/bin/killall")) -> [(restart: Restart, ok: Bool)] {
        restarts.compactMap { restart in
            guard let process = restart.process else { return nil }
            let task = Process()
            task.executableURL = killall
            task.arguments = [process]
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice
            do {
                try task.run()
                task.waitUntilExit()
                return (restart, task.terminationStatus == 0)
            } catch {
                return (restart, false)
            }
        }
    }
}
