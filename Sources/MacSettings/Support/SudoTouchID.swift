//
//  SudoTouchID.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//
//  Touch ID for sudo, the way that survives macOS updates: an
//  `auth sufficient pam_tid.so` line in /etc/pam.d/sudo_local, which macOS 14+
//  includes from /etc/pam.d/sudo and ships a template for. /etc/pam.d/sudo
//  itself is replaced by updates and is never touched — not even named in a
//  command this writes. The file is root's, so this reads it and hands back
//  the one sudo line that makes the change; it writes nothing itself.
//
//  Pure: every function takes the file's text.
//

import Foundation

public enum SudoTouchID {

    /// The catalogue-style id: `settings get sudo.touch-id`.
    public static let id = "sudo.touch-id"

    /// The file that holds it.
    public static let path = "/etc/pam.d/sudo_local"

    /// Apple's template for it.
    public static let templatePath = "/etc/pam.d/sudo_local.template"

    /// The line, spaced as Apple's template spaces it.
    public static let line = "auth       sufficient     pam_tid.so"

    /// Where it stands.
    public enum State: String, Codable, Sendable, Equatable {
        /// An uncommented pam_tid line is there.
        case on
        /// The file is there without one (or with it commented out).
        case off
        /// There is no sudo_local.
        case noFile = "no-file"
    }

    /// Whether `text` (sudo_local's contents, `nil` when there is none) turns Touch ID on.
    public static func state(_ text: String?) -> State {
        guard let text else { return .noFile }
        return lines(text).contains(where: isActive) ? .on : .off
    }

    /// sudo_local as it should be, or `nil` when it should not exist.
    ///
    /// On: a commented pam_tid line is uncommented (the template's way);
    /// failing that the line is added — after any pam_reattach line, which
    /// must come first for Touch ID to reach tmux. Off: every pam_tid line is
    /// commented out, and a file left with nothing but comments is removed.
    /// Every other line is kept as it was.
    public static func edited(_ text: String?, template: String?, on: Bool) -> String? {
        var rows = text.map(lines) ?? (on ? template.map(lines) ?? [] : [])
        if on {
            if rows.contains(where: isActive) { return text }
            if let commented = rows.firstIndex(where: isCommentedTID) {
                rows[commented] = uncomment(rows[commented])
            } else {
                let after = rows.lastIndex { isActive($0) == false && $0.contains("pam_reattach") && !isComment($0) }
                rows.insert(line, at: after.map { $0 + 1 } ?? rows.firstIndex { !isComment($0) && !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? rows.count)
            }
            return rows.joined(separator: "\n") + "\n"
        }
        guard text != nil else { return nil }
        rows = rows.map { isActive($0) ? "#" + $0 : $0 }
        let kept = rows.filter { !isComment($0) && !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return kept.isEmpty ? nil : rows.joined(separator: "\n") + "\n"
    }

    /// The one line a person runs to go from `current` to `target`; `nil`
    /// when they are the same.
    public static func command(current: String?, target: String?) -> String? {
        guard current != target else { return nil }
        guard let target else { return "sudo rm \(path)" }
        let quoted = lines(target).map(shellQuoted).joined(separator: " ")
        return "printf '%s\\n' \(quoted) | sudo tee \(path) >/dev/null"
    }

    // MARK: - Lines

    static func lines(_ text: String) -> [String] {
        var rows = text.components(separatedBy: "\n")
        if rows.last == "" { rows.removeLast() }
        return rows
    }

    static func isComment(_ row: String) -> Bool {
        row.trimmingCharacters(in: .whitespaces).hasPrefix("#")
    }

    /// `auth sufficient pam_tid.so`, any spacing, not commented.
    static func isActive(_ row: String) -> Bool {
        row.range(of: #"^\s*auth\s+sufficient\s+pam_tid\.so(\s|$)"#, options: .regularExpression) != nil
    }

    static func isCommentedTID(_ row: String) -> Bool {
        isComment(row) && isActive(uncomment(row))
    }

    /// The row without its leading `#`s.
    static func uncomment(_ row: String) -> String {
        var rest = Substring(row.drop { $0 == " " || $0 == "\t" })
        while rest.first == "#" { rest = rest.dropFirst() }
        return String(rest)
    }

    static func shellQuoted(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
