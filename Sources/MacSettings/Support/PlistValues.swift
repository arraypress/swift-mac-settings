//
//  PlistValues.swift
//  MacSettings
//
//  Created by David Sherlock on 2026.
//
//
//  StoredValue to and from the CoreFoundation property-list objects
//  CFPreferences speaks. A CFBoolean is a bool, never the number 1; a CFNumber
//  is a real only when CoreFoundation says it is a float type.
//

import CoreFoundation
import Foundation

enum PlistValues {

    static func stored(_ value: CFPropertyList?) -> StoredValue {
        guard let value else { return .absent }
        let type = CFGetTypeID(value)
        if type == CFBooleanGetTypeID() { return .bool(CFBooleanGetValue((value as! CFBoolean))) }
        if type == CFNumberGetTypeID() {
            let number = value as! CFNumber
            if CFNumberIsFloatType(number) {
                var double = 0.0
                CFNumberGetValue(number, .doubleType, &double)
                return .real(double)
            }
            var long: Int64 = 0
            CFNumberGetValue(number, .sInt64Type, &long)
            return .int(Int(long))
        }
        if type == CFStringGetTypeID() { return .string(value as! String) }
        let wrapped = ["v": value] as CFDictionary
        if let data = try? PropertyListSerialization.data(fromPropertyList: wrapped, format: .binary, options: 0) {
            return .plist(data)
        }
        return .plist(Data())
    }

    static func object(_ stored: StoredValue) -> CFPropertyList? {
        switch stored {
        case .absent: return nil
        case .bool(let b): return (b ? kCFBooleanTrue : kCFBooleanFalse)
        case .int(let i):
            var long = Int64(i)
            return CFNumberCreate(nil, .sInt64Type, &long)
        case .real(let r):
            var double = r
            return CFNumberCreate(nil, .doubleType, &double)
        case .string(let s): return s as CFString
        case .plist(let data):
            let decoded = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            return (decoded as? [String: Any])?["v"] as CFPropertyList?
        }
    }
}
