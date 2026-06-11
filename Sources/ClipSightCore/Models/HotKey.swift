import AppKit
import Carbon
import Foundation

public enum HotKeyModifier: CaseIterable, Sendable {
    case control
    case option
    case shift
    case command

    public var carbonFlag: UInt32 {
        switch self {
        case .control:
            UInt32(controlKey)
        case .option:
            UInt32(optionKey)
        case .shift:
            UInt32(shiftKey)
        case .command:
            UInt32(cmdKey)
        }
    }

    public var displayGlyph: String {
        switch self {
        case .control:
            "⌃"
        case .option:
            "⌥"
        case .shift:
            "⇧"
        case .command:
            "⌘"
        }
    }
}

public struct HotKey: Codable, Equatable, Sendable {
    public let keyCode: UInt32
    public let carbonModifiers: UInt32
    public let keyEquivalent: String

    public init(keyCode: UInt32, carbonModifiers: UInt32, keyEquivalent: String) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        self.keyEquivalent = keyEquivalent.uppercased()
    }

    public init?(event: NSEvent) {
        let carbonModifiers = Self.carbonModifiers(from: event.modifierFlags)
        let keyEquivalent = Self.keyEquivalent(
            keyCode: event.keyCode,
            charactersIgnoringModifiers: event.charactersIgnoringModifiers
        )

        guard !keyEquivalent.isEmpty else {
            return nil
        }

        self.init(
            keyCode: UInt32(event.keyCode),
            carbonModifiers: carbonModifiers,
            keyEquivalent: keyEquivalent
        )
    }

    public var displayString: String {
        let modifiers = HotKeyModifier.allCases
            .filter { carbonModifiers & $0.carbonFlag != 0 }
            .map(\.displayGlyph)
            .joined()

        return modifiers + keyEquivalent.uppercased()
    }

    public var isUsable: Bool {
        !keyEquivalent.isEmpty && carbonModifiers != 0
    }

    public static func carbonModifiers(from modifierFlags: NSEvent.ModifierFlags) -> UInt32 {
        let flags = modifierFlags.intersection(.deviceIndependentFlagsMask)
        var carbonModifiers: UInt32 = 0

        if flags.contains(.control) {
            carbonModifiers |= HotKeyModifier.control.carbonFlag
        }

        if flags.contains(.option) {
            carbonModifiers |= HotKeyModifier.option.carbonFlag
        }

        if flags.contains(.shift) {
            carbonModifiers |= HotKeyModifier.shift.carbonFlag
        }

        if flags.contains(.command) {
            carbonModifiers |= HotKeyModifier.command.carbonFlag
        }

        return carbonModifiers
    }

    private static func keyEquivalent(keyCode: UInt16, charactersIgnoringModifiers: String?) -> String {
        if let charactersIgnoringModifiers,
           let first = charactersIgnoringModifiers.unicodeScalars.first,
           !CharacterSet.controlCharacters.contains(first) {
            return String(charactersIgnoringModifiers.prefix(1)).uppercased()
        }

        switch keyCode {
        case 36:
            return "Return"
        case 48:
            return "Tab"
        case 49:
            return "Space"
        case 51:
            return "Delete"
        case 53:
            return "Esc"
        case 71:
            return "Clear"
        case 76:
            return "Enter"
        case 96:
            return "F5"
        case 97:
            return "F6"
        case 98:
            return "F7"
        case 99:
            return "F3"
        case 100:
            return "F8"
        case 101:
            return "F9"
        case 103:
            return "F11"
        case 105:
            return "F13"
        case 106:
            return "F16"
        case 107:
            return "F14"
        case 109:
            return "F10"
        case 111:
            return "F12"
        case 113:
            return "F15"
        case 114:
            return "Help"
        case 115:
            return "Home"
        case 116:
            return "Page Up"
        case 117:
            return "Forward Delete"
        case 118:
            return "F4"
        case 119:
            return "End"
        case 120:
            return "F2"
        case 121:
            return "Page Down"
        case 122:
            return "F1"
        case 123:
            return "Left"
        case 124:
            return "Right"
        case 125:
            return "Down"
        case 126:
            return "Up"
        default:
            return ""
        }
    }
}
