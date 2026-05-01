import AppKit
import Carbon
import Foundation

enum GlobalShortcutRegistrationError: Error, Equatable, LocalizedError {
    case invalidShortcut
    case registrationFailed(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidShortcut:
            return "Choose a shortcut with at least one modifier key."
        case .registrationFailed:
            return "That shortcut could not be registered. It may already be used by macOS or another app."
        }
    }
}

protocol GlobalShortcutClient: AnyObject {
    var onShortcut: (() -> Void)? { get set }

    func register(shortcut: KeyboardShortcut) throws
    func unregister()
}

@MainActor
final class GlobalShortcutRuntime {
    private let client: GlobalShortcutClient
    private var registeredShortcut: KeyboardShortcut?

    var onShortcut: (() -> Void)? {
        get { client.onShortcut }
        set { client.onShortcut = newValue }
    }

    init(client: GlobalShortcutClient? = nil) {
        self.client = client ?? GlobalShortcutRuntime.makeDefaultClient()
    }

    func apply(shortcut: KeyboardShortcut?) throws {
        guard let shortcut else {
            client.unregister()
            registeredShortcut = nil
            return
        }

        guard shortcut.isValid else {
            throw GlobalShortcutRegistrationError.invalidShortcut
        }

        let previous = registeredShortcut
        do {
            try client.register(shortcut: shortcut)
            registeredShortcut = shortcut
        } catch {
            if let previous {
                try? client.register(shortcut: previous)
            } else {
                client.unregister()
            }
            throw error
        }
    }

    func invalidate() {
        client.unregister()
        registeredShortcut = nil
    }

    func triggerForTesting() {
        client.onShortcut?()
    }

    private static func makeDefaultClient(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        classLookup: (String) -> AnyClass? = NSClassFromString
    ) -> GlobalShortcutClient {
        if let rawValue = environment["XCTestConfigurationFilePath"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawValue.isEmpty {
            return NullGlobalShortcutClient()
        }

        if classLookup("XCTestCase") != nil || classLookup("XCTest") != nil {
            return NullGlobalShortcutClient()
        }

        return CarbonGlobalShortcutClient()
    }
}

final class NullGlobalShortcutClient: GlobalShortcutClient {
    var onShortcut: (() -> Void)?

    func register(shortcut: KeyboardShortcut) throws {}

    func unregister() {}
}

final class CarbonGlobalShortcutClient: GlobalShortcutClient {
    var onShortcut: (() -> Void)?

    private var eventHotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let hotKeyID = EventHotKeyID(signature: OSType(0x43505850), id: 1)

    func register(shortcut: KeyboardShortcut) throws {
        unregisterHotKeyOnly()

        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            shortcut.carbonModifierFlags,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &eventHotKey
        )
        guard status == noErr else {
            eventHotKey = nil
            throw GlobalShortcutRegistrationError.registrationFailed(status: status)
        }

        installHandlerIfNeeded()
    }

    func unregister() {
        unregisterHotKeyOnly()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    private func unregisterHotKeyOnly() {
        if let eventHotKey {
            UnregisterEventHotKey(eventHotKey)
            self.eventHotKey = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr, hotKeyID.id == 1 else { return noErr }
                let client = Unmanaged<CarbonGlobalShortcutClient>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    client.onShortcut?()
                }
                return noErr
            },
            1,
            &eventSpec,
            selfPointer,
            &eventHandler
        )
    }

    deinit {
        unregister()
    }
}
