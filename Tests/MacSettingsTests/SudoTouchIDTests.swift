//
//  SudoTouchIDTests.swift
//  MacSettingsTests
//
//  Created by David Sherlock on 2026.
//
//  sudo_local read and edited as text — fixtures only; /etc is never touched.
//

import Foundation
import Testing
@testable import MacSettings

struct SudoTouchIDTests {

    /// macOS 27's /etc/pam.d/sudo_local.template, byte for byte.
    let template = """
        # sudo_local: local config file which survives system update and is included for sudo
        # uncomment following line to enable Touch ID for sudo
        #auth       sufficient     pam_tid.so

        """

    @Test func states() {
        #expect(SudoTouchID.state(nil) == .noFile)
        #expect(SudoTouchID.state(template) == .off)
        #expect(SudoTouchID.state("auth sufficient pam_tid.so\n") == .on)
        #expect(SudoTouchID.state("  auth\tsufficient\tpam_tid.so  # touch\n") == .on)
        #expect(SudoTouchID.state("auth required pam_tid.so\n") == .off)
        #expect(SudoTouchID.state("auth sufficient pam_tid.so.bak\n") == .off)
        #expect(SudoTouchID.state("# auth sufficient pam_tid.so\n") == .off)
    }

    @Test func onFromNothingIsTheTemplateUncommented() {
        let made = SudoTouchID.edited(nil, template: template, on: true)
        #expect(made == """
            # sudo_local: local config file which survives system update and is included for sudo
            # uncomment following line to enable Touch ID for sudo
            auth       sufficient     pam_tid.so

            """)
        #expect(SudoTouchID.state(made) == .on)
        #expect(SudoTouchID.edited(nil, template: nil, on: true) == SudoTouchID.line + "\n")
    }

    @Test func onKeepsEveryOtherLineAndGoesAfterPamReattach() {
        let mine = "# mine\nauth       optional       /opt/homebrew/lib/pam/pam_reattach.so\naccount required pam_permit.so\n"
        let made = SudoTouchID.edited(mine, template: template, on: true)
        #expect(made == "# mine\nauth       optional       /opt/homebrew/lib/pam/pam_reattach.so\n\(SudoTouchID.line)\naccount required pam_permit.so\n")
        let plain = SudoTouchID.edited("# mine\naccount required pam_permit.so\n", template: nil, on: true)
        #expect(plain == "# mine\n\(SudoTouchID.line)\naccount required pam_permit.so\n")
        // Already on: unchanged, byte for byte.
        let on = "auth sufficient pam_tid.so\n"
        #expect(SudoTouchID.edited(on, template: template, on: true) == on)
        // Commented out twice over (an off, then another): still found and uncommented.
        #expect(SudoTouchID.edited("##auth sufficient pam_tid.so\n", template: nil, on: true) == "auth sufficient pam_tid.so\n")
    }

    @Test func offCommentsTheLineOutAndRemovesAFileWithNothingElse() {
        let made = SudoTouchID.edited("auth optional pam_reattach.so\nauth sufficient pam_tid.so\n", template: template, on: false)
        #expect(made == "auth optional pam_reattach.so\n#auth sufficient pam_tid.so\n")
        let onlyIt = SudoTouchID.edited(SudoTouchID.edited(nil, template: template, on: true), template: template, on: false)
        #expect(onlyIt == nil)
        #expect(SudoTouchID.edited(nil, template: template, on: false) == nil)
    }

    @Test func theCommandIsOneLineToSudoLocalOnly() throws {
        #expect(SudoTouchID.command(current: nil, target: nil) == nil)
        #expect(SudoTouchID.command(current: "x\n", target: "x\n") == nil)
        #expect(SudoTouchID.command(current: "x\n", target: nil) == "sudo rm /etc/pam.d/sudo_local")
        let command = try #require(SudoTouchID.command(current: nil, target: "# it's mine\nauth sufficient pam_tid.so\n"))
        #expect(command == #"printf '%s\n' '# it'\''s mine' 'auth sufficient pam_tid.so' | sudo tee /etc/pam.d/sudo_local >/dev/null"#)
        #expect(!command.contains("/etc/pam.d/sudo "))
        #expect(!command.contains("\n"))
    }

    @Test func theCommandWritesWhatEditedSays() throws {
        // Run the printf half (no sudo) and compare what it prints.
        let target = try #require(SudoTouchID.edited(nil, template: template, on: true))
        let command = try #require(SudoTouchID.command(current: nil, target: target))
        let printf = String(command[..<command.range(of: " | sudo")!.lowerBound])
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", printf]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()
        #expect(String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self) == target.replacingOccurrences(of: "\n\n", with: "\n\n"))
    }
}
