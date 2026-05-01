import AppKit

enum ShortcutCapturePanelResult: Equatable {
    case cancelled
    case cleared
    case saved(KeyboardShortcut)
}

@MainActor
protocol ShortcutCapturePanelPresenter {
    func presentShortcutCapture(currentShortcut: KeyboardShortcut?) -> ShortcutCapturePanelResult
}

@MainActor
struct SystemShortcutCapturePanelPresenter: ShortcutCapturePanelPresenter {
    func presentShortcutCapture(currentShortcut: KeyboardShortcut?) -> ShortcutCapturePanelResult {
        let alert = NSAlert()
        alert.messageText = "Menu Bar Label Shortcut"
        alert.informativeText = "Press a shortcut to reveal CodexPill limits from anywhere."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        let saveButton = alert.buttons[0]
        saveButton.isEnabled = currentShortcut != nil

        let label = NSTextField(labelWithString: currentShortcut?.displayTitle ?? "Waiting for shortcut")
        label.alignment = .center
        label.font = .monospacedSystemFont(ofSize: 16, weight: .medium)
        label.frame = NSRect(x: 0, y: 0, width: 260, height: 32)
        alert.accessoryView = label

        var capturedShortcut = currentShortcut
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if let shortcut = KeyboardShortcut(event: event) {
                capturedShortcut = shortcut
                label.stringValue = shortcut.displayTitle
                saveButton.isEnabled = true
            } else {
                capturedShortcut = nil
                label.stringValue = "Press a shortcut with modifier keys"
                saveButton.isEnabled = false
            }
            return nil
        }
        defer {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            guard let capturedShortcut, capturedShortcut.isValid else {
                return .cancelled
            }
            return .saved(capturedShortcut)
        case .alertSecondButtonReturn:
            return .cleared
        default:
            return .cancelled
        }
    }
}
