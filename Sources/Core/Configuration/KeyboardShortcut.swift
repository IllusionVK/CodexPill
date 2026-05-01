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
        keyCode: 37,
        modifiers: [.control, .option, .command]
    )

    var isValid: Bool {
        !modifiers.isEmpty
    }

    init(keyCode: UInt16, modifiers: Modifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}
