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
        let letters: [Int: String] = [
            kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D",
            kVK_ANSI_E: "E", kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H",
            kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
            kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P",
            kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
            kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
            kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z"
        ]

        if let letter = letters[Int(keyCode)] {
            return letter
        }

        switch Int(keyCode) {
        case kVK_Space:
            return "Space"
        case kVK_Return:
            return "Return"
        case kVK_Escape:
            return "Esc"
        default:
            return "Key \(keyCode)"
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
