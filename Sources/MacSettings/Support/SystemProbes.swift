//
//  SystemProbes.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//
//  Reading back what the system-toggle helpers change. MEASURED on a Mac15,10
//  (macOS 27.0.1) with only an external Samsung display:
//  - Low Power Mode: ProcessInfo.isLowPowerModeEnabled (public).
//  - Night Shift: CoreBrightness's CBBlueLightClient -getBlueLightStatus:,
//    whose second byte is "enabled" (private framework, read only).
//  - True Tone: CBTrueToneClient -enabled, and -available, which is false on
//    this display — so True Tone is not readable, and not written, here.
//  - Bluetooth: IOBluetoothHostController.default().powerState (public).
//  - Appearance: NSApp.effectiveAppearance (AppleInterfaceStyle lags; see below).
//  - Brightness: DisplayServices can neither read nor change it on this
//    external display (DisplayServicesCanChangeBrightness false;
//    GetBrightness returns 1000). On a built-in display it can.
//

import AppKit
import CoreGraphics
import Foundation
import IOBluetooth

enum SystemProbes {

    static let names = ["low-power", "night-shift", "true-tone", "bluetooth", "brightness", "appearance"]

    static func read(_ probe: String) -> ProbeReading {
        switch probe {
        case "low-power": return .value(.bool(ProcessInfo.processInfo.isLowPowerModeEnabled))
        case "night-shift": return nightShift()
        case "true-tone": return trueTone()
        case "bluetooth":
            guard let controller = IOBluetoothHostController.default() else { return .unavailable("this Mac has no Bluetooth controller") }
            return .value(.bool(controller.powerState == kBluetoothHCIPowerStateON))
        case "brightness": return brightness()
        case "appearance": return appearance()
        default: return .unavailable("no reader called \(probe)")
        }
    }

    nonisolated(unsafe) private static let coreBrightness: UnsafeMutableRawPointer? =
        dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_NOW)

    static func nightShift() -> ProbeReading {
        guard coreBrightness != nil, let type = NSClassFromString("CBBlueLightClient") as? NSObject.Type else {
            return .unavailable("Night Shift's status could not be read (CoreBrightness)")
        }
        let client = type.init()
        let selector = NSSelectorFromString("getBlueLightStatus:")
        guard client.responds(to: selector) else { return .unavailable("Night Shift's status could not be read") }
        typealias Get = @convention(c) (AnyObject, Selector, UnsafeMutableRawPointer) -> Bool
        var status = [UInt8](repeating: 0, count: 64)
        let ok = status.withUnsafeMutableBytes { unsafeBitCast(client.method(for: selector), to: Get.self)(client, selector, $0.baseAddress!) }
        return ok ? .value(.bool(status[1] != 0)) : .unavailable("Night Shift's status could not be read")
    }

    static func trueTone() -> ProbeReading {
        guard coreBrightness != nil, let type = NSClassFromString("CBTrueToneClient") as? NSObject.Type else {
            return .unavailable("True Tone's status could not be read (CoreBrightness)")
        }
        let client = type.init()
        typealias Flag = @convention(c) (AnyObject, Selector) -> Bool
        func flag(_ name: String) -> Bool? {
            let selector = NSSelectorFromString(name)
            guard client.responds(to: selector) else { return nil }
            return unsafeBitCast(client.method(for: selector), to: Flag.self)(client, selector)
        }
        guard flag("supported") == true, flag("available") == true else { return .unavailable("True Tone is not available on this display") }
        guard let enabled = flag("enabled") else { return .unavailable("True Tone's status could not be read") }
        return .value(.bool(enabled))
    }

    /// The running appearance, as a fresh process's NSApp sees it.
    ///
    /// MEASURED: after Set Appearance switched to light, AppleInterfaceStyle
    /// still read "Dark" (defaults, CFPreferences), while System Events'
    /// dark mode and NSApp.effectiveAppearance both said light. The key is
    /// not the read-back; this is.
    static func appearance() -> ProbeReading {
        let match = NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
        return .value(.string(match == .darkAqua ? "Dark" : "Light"))
    }

    nonisolated(unsafe) private static let displayServices: UnsafeMutableRawPointer? =
        dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)

    static func brightness() -> ProbeReading {
        let display = CGMainDisplayID()
        typealias Can = @convention(c) (UInt32) -> Bool
        typealias Get = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
        guard let library = displayServices, let canSymbol = dlsym(library, "DisplayServicesCanChangeBrightness"),
              let getSymbol = dlsym(library, "DisplayServicesGetBrightness") else {
            return .unavailable("brightness could not be read (DisplayServices)")
        }
        guard unsafeBitCast(canSymbol, to: Can.self)(display) else {
            return .unavailable("macOS cannot read or change this display's brightness")
        }
        var level: Float = -1
        guard unsafeBitCast(getSymbol, to: Get.self)(display, &level) == 0, (0...1).contains(level) else {
            return .unavailable("brightness could not be read")
        }
        return .value(.double((Double(level) * 100).rounded() / 100))
    }
}
