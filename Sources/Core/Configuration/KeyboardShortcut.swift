import AppKit
import Carbon
import Foundation

struct KeyboardShortcut: Codable, Equatable {
    struct Modifiers: OptionSet, Codable, Equatable {
        let rawValue: UInt

        static let control = Modifiers(rawValue: 1 << 0)
        static let option = Modifiers(rawValue: 1 << 1)
        static let command = Modifiers(rawValue: 1 << 2)
        static let shift = Modifiers(rawValue: 1 << 3)

        init(rawValue: UInt) {
            self.rawValue = rawValue
        }
    }

    let keyCode: UInt16
    let modifiers: Modifiers

    static let defaultRevealStatusItemTitle = KeyboardShortcut(
        keyCode: UInt16(kVK_ANSI_L),
        modifiers: [.control, .option, .command]
    )

    var isValid: Bool {
        !modifiers.isEmpty
    }

    var displayTitle: String {
        "\(modifiers.displayTitle)\(Self.keyDisplayTitle(for: keyCode))"
    }

    var carbonModifierFlags: UInt32 {
        var flags: UInt32 = 0
        if modifiers.contains(.control) { flags |= UInt32(controlKey) }
        if modifiers.contains(.option) { flags |= UInt32(optionKey) }
        if modifiers.contains(.command) { flags |= UInt32(cmdKey) }
        if modifiers.contains(.shift) { flags |= UInt32(shiftKey) }
        return flags
    }

    var appKitModifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers.contains(.control) { flags.insert(.control) }
        if modifiers.contains(.option) { flags.insert(.option) }
        if modifiers.contains(.command) { flags.insert(.command) }
        if modifiers.contains(.shift) { flags.insert(.shift) }
        return flags
    }

    var appKitKeyEquivalent: String? {
        Self.keyEquivalent(for: keyCode)
    }

    init(keyCode: UInt16, modifiers: Modifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init?(event: NSEvent) {
        let modifiers = Modifiers(eventModifierFlags: event.modifierFlags)
        guard !modifiers.isEmpty else { return nil }
        self.init(keyCode: event.keyCode, modifiers: modifiers)
    }

    private static func keyDisplayTitle(for keyCode: UInt16) -> String {
        if let keyEquivalent = keyEquivalent(for: keyCode) {
            switch keyEquivalent {
            case " ":
                return "Space"
            case "\r":
                return "Return"
            case "\u{1b}":
                return "Esc"
            default:
                return keyEquivalent.uppercased()
            }
        }

        return "Key \(keyCode)"
    }

    private static func keyEquivalent(for keyCode: UInt16) -> String? {
        let letters: [Int: String] = [
            kVK_ANSI_A: "a", kVK_ANSI_B: "b", kVK_ANSI_C: "c", kVK_ANSI_D: "d",
            kVK_ANSI_E: "e", kVK_ANSI_F: "f", kVK_ANSI_G: "g", kVK_ANSI_H: "h",
            kVK_ANSI_I: "i", kVK_ANSI_J: "j", kVK_ANSI_K: "k", kVK_ANSI_L: "l",
            kVK_ANSI_M: "m", kVK_ANSI_N: "n", kVK_ANSI_O: "o", kVK_ANSI_P: "p",
            kVK_ANSI_Q: "q", kVK_ANSI_R: "r", kVK_ANSI_S: "s", kVK_ANSI_T: "t",
            kVK_ANSI_U: "u", kVK_ANSI_V: "v", kVK_ANSI_W: "w", kVK_ANSI_X: "x",
            kVK_ANSI_Y: "y", kVK_ANSI_Z: "z"
        ]

        switch Int(keyCode) {
        case kVK_Space:
            return " "
        case kVK_Return:
            return "\r"
        case kVK_Escape:
            return "\u{1b}"
        default:
            return letters[Int(keyCode)]
        }
    }
}

extension KeyboardShortcut.Modifiers {
    init(eventModifierFlags: NSEvent.ModifierFlags) {
        var modifiers: Self = []
        if eventModifierFlags.contains(.control) { modifiers.insert(.control) }
        if eventModifierFlags.contains(.option) { modifiers.insert(.option) }
        if eventModifierFlags.contains(.command) { modifiers.insert(.command) }
        if eventModifierFlags.contains(.shift) { modifiers.insert(.shift) }
        self = modifiers
    }

    var displayTitle: String {
        var title = ""
        if contains(.control) { title += "⌃" }
        if contains(.option) { title += "⌥" }
        if contains(.shift) { title += "⇧" }
        if contains(.command) { title += "⌘" }
        return title
    }
}
