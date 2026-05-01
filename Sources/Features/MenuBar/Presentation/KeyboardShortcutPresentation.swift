import AppKit
import Foundation

struct KeyboardShortcutPresentation {
    let displayTitle: String
    let keyEquivalent: String?
    let modifierFlags: NSEvent.ModifierFlags

    init(shortcut: KeyboardShortcut) {
        self.keyEquivalent = Self.keyEquivalent(for: shortcut.keyCode)
        self.displayTitle = "\(Self.modifierDisplayTitle(for: shortcut.modifiers))\(Self.keyDisplayTitle(for: shortcut.keyCode))"
        self.modifierFlags = Self.modifierFlags(for: shortcut.modifiers)
    }

    private static func modifierFlags(for modifiers: KeyboardShortcut.Modifiers) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers.contains(.control) { flags.insert(.control) }
        if modifiers.contains(.option) { flags.insert(.option) }
        if modifiers.contains(.command) { flags.insert(.command) }
        if modifiers.contains(.shift) { flags.insert(.shift) }
        return flags
    }

    private static func modifierDisplayTitle(for modifiers: KeyboardShortcut.Modifiers) -> String {
        var title = ""
        if modifiers.contains(.control) { title += "⌃" }
        if modifiers.contains(.option) { title += "⌥" }
        if modifiers.contains(.shift) { title += "⇧" }
        if modifiers.contains(.command) { title += "⌘" }
        return title
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
            0: "a", 11: "b", 8: "c", 2: "d",
            14: "e", 3: "f", 5: "g", 4: "h",
            34: "i", 38: "j", 40: "k", 37: "l",
            46: "m", 45: "n", 31: "o", 35: "p",
            12: "q", 15: "r", 1: "s", 17: "t",
            32: "u", 9: "v", 13: "w", 7: "x",
            16: "y", 6: "z"
        ]

        switch Int(keyCode) {
        case 49:
            return " "
        case 36:
            return "\r"
        case 53:
            return "\u{1b}"
        default:
            return letters[Int(keyCode)]
        }
    }
}
