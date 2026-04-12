import AppKit

struct MenuBarTextInputAlertRequest {
    let messageText: String
    let informativeText: String
    let fieldTitle: String
    let placeholder: String
    let confirmTitle: String
    let cancelTitle: String
}

struct MenuBarHostInputAlertRequest {
    let messageText: String
    let informativeText: String
    let nameFieldTitle: String
    let namePlaceholder: String
    let targetFieldTitle: String
    let targetPlaceholder: String
    let testTitle: String
    let confirmTitle: String
    let cancelTitle: String
}

struct MenuBarHostInput: Equatable {
    let name: String
    let sshTarget: String
}

struct MenuBarConfirmationAlertRequest {
    let messageText: String
    let informativeText: String
    let confirmTitle: String
    let cancelTitle: String
}

struct MenuBarInfoAlertRequest {
    let messageText: String
    let informativeText: String
    let style: NSAlert.Style
    let buttonTitle: String
}

@MainActor
final class MenuBarAlertPresenter {
    func presentTextInput(_ request: MenuBarTextInputAlertRequest) -> String? {
        let field = NSTextField(string: "")
        field.placeholderString = request.placeholder

        let alert = NSAlert()
        alert.messageText = request.messageText
        alert.informativeText = request.informativeText
        alert.alertStyle = .informational
        alert.accessoryView = textFieldAccessoryView(title: request.fieldTitle, field: field)
        alert.addButton(withTitle: request.confirmTitle)
        alert.addButton(withTitle: request.cancelTitle)

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return field.stringValue
    }

    func presentValidatedHostInput(
        _ request: MenuBarHostInputAlertRequest,
        initialValue: MenuBarHostInput = .init(name: "", sshTarget: ""),
        validator: @escaping @MainActor (MenuBarHostInput) async -> String?
    ) -> MenuBarHostInput? {
        HostInputPanelController(
            request: request,
            initialValue: initialValue,
            validator: validator
        ).runModal()
    }

    func presentConfirmation(_ request: MenuBarConfirmationAlertRequest) -> Bool {
        let alert = NSAlert()
        alert.messageText = request.messageText
        alert.informativeText = request.informativeText
        alert.alertStyle = .informational
        alert.addButton(withTitle: request.confirmTitle)
        alert.addButton(withTitle: request.cancelTitle)
        return alert.runModal() == .alertFirstButtonReturn
    }

    func presentInfo(_ request: MenuBarInfoAlertRequest) {
        let alert = NSAlert()
        alert.messageText = request.messageText
        alert.informativeText = request.informativeText
        alert.alertStyle = request.style
        alert.addButton(withTitle: request.buttonTitle)
        alert.runModal()
    }

    private func textFieldAccessoryView(title: String, field: NSTextField) -> NSView {
        configureAlertTextField(field)

        let stack = labeledField(title: title, field: field)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.layoutSubtreeIfNeeded()
        let fittingHeight = max(50, stack.fittingSize.height)

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: fittingHeight))
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    private func labeledField(title: String, field: NSTextField) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 12, weight: .medium)

        let stack = NSStackView(views: [label, field])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        return stack
    }

    private func configureAlertTextField(_ field: NSTextField) {
        field.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            field.widthAnchor.constraint(equalToConstant: 320),
            field.heightAnchor.constraint(equalToConstant: 26)
        ])
    }
}

@MainActor
private final class HostInputPanelController: NSObject, NSWindowDelegate, NSTextFieldDelegate {
    private let request: MenuBarHostInputAlertRequest
    private let validator: @MainActor (MenuBarHostInput) async -> String?
    private let panel: NSPanel
    private let nameField: NSTextField
    private let targetField: NSTextField
    private let statusLabel: NSTextField
    private let testButton: NSButton
    private let addButton: NSButton
    private var result: MenuBarHostInput?
    private var validatedInput: MenuBarHostInput?
    private var isTesting = false

    init(
        request: MenuBarHostInputAlertRequest,
        initialValue: MenuBarHostInput,
        validator: @escaping @MainActor (MenuBarHostInput) async -> String?
    ) {
        self.request = request
        self.validator = validator
        self.panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 224),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        self.nameField = NSTextField(string: initialValue.name)
        self.targetField = NSTextField(string: initialValue.sshTarget)
        self.statusLabel = NSTextField(labelWithString: "")
        self.testButton = NSButton(title: request.testTitle, target: nil, action: nil)
        self.addButton = NSButton(title: request.confirmTitle, target: nil, action: nil)
        super.init()
        buildUI()
    }

    func runModal() -> MenuBarHostInput? {
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.runModal(for: panel)
        panel.orderOut(nil)
        return result
    }

    func windowWillClose(_ notification: Notification) {
        if NSApp.modalWindow == panel {
            NSApp.stopModal()
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        validatedInput = nil
        addButton.isEnabled = false
        if !isTesting {
            setStatus("", color: .secondaryLabelColor)
        }
    }

    @objc
    private func handleTest(_ sender: Any?) {
        let input = currentInput
        setTestingState(true)
        setStatus("Testing connection…", color: .secondaryLabelColor)

        Task { @MainActor in
            let validationError = await validator(input)
            guard panel.isVisible else { return }
            setTestingState(false)

            if currentInput != input {
                setStatus("", color: .secondaryLabelColor)
                return
            }

            if let validationError {
                validatedInput = nil
                addButton.isEnabled = false
                setStatus(validationError, color: .systemRed)
            } else {
                validatedInput = input
                addButton.isEnabled = true
                setStatus("Connection valid.", color: .systemGreen)
            }
        }
    }

    @objc
    private func handleAdd(_ sender: Any?) {
        guard addButton.isEnabled else { return }
        result = currentInput
        NSApp.stopModal()
        panel.close()
    }

    @objc
    private func handleCancel(_ sender: Any?) {
        result = nil
        NSApp.stopModal()
        panel.close()
    }

    private func buildUI() {
        panel.title = request.messageText
        panel.isReleasedWhenClosed = false
        panel.level = .modalPanel
        panel.delegate = self

        nameField.placeholderString = request.namePlaceholder
        targetField.placeholderString = request.targetPlaceholder
        nameField.delegate = self
        targetField.delegate = self

        [nameField, targetField].forEach(configureHostInputField)

        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 2
        statusLabel.textColor = .secondaryLabelColor

        testButton.target = self
        testButton.action = #selector(handleTest(_:))
        addButton.target = self
        addButton.action = #selector(handleAdd(_:))
        addButton.isEnabled = false

        let cancelButton = NSButton(title: request.cancelTitle, target: self, action: #selector(handleCancel(_:)))
        cancelButton.keyEquivalent = "\u{1b}"
        addButton.keyEquivalent = "\r"

        let titleLabel = NSTextField(labelWithString: request.messageText)
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)

        let infoLabel = NSTextField(wrappingLabelWithString: request.informativeText)
        infoLabel.textColor = .secondaryLabelColor
        infoLabel.font = .systemFont(ofSize: 12)

        let contentStack = NSStackView(views: [
            titleLabel,
            infoLabel,
            labeledField(title: request.nameFieldTitle, field: nameField),
            labeledField(title: request.targetFieldTitle, field: targetField),
            statusLabel
        ])
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 10
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let buttonStack = NSStackView(views: [cancelButton, testButton, addButton])
        buttonStack.orientation = .horizontal
        buttonStack.alignment = .centerY
        buttonStack.spacing = 8
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(contentStack)
        container.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),

            buttonStack.topAnchor.constraint(equalTo: contentStack.bottomAnchor, constant: 16),
            buttonStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            buttonStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),

            container.widthAnchor.constraint(equalToConstant: 420)
        ])

        panel.contentView = container
        panel.initialFirstResponder = targetField
    }

    private func labeledField(title: String, field: NSTextField) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 12, weight: .medium)

        let stack = NSStackView(views: [label, field])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        return stack
    }

    private func configureHostInputField(_ field: NSTextField) {
        field.translatesAutoresizingMaskIntoConstraints = false
        field.controlSize = .regular
        field.focusRingType = .none
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        NSLayoutConstraint.activate([
            field.heightAnchor.constraint(equalToConstant: 22),
            field.widthAnchor.constraint(equalToConstant: 380)
        ])
    }

    private func setTestingState(_ testing: Bool) {
        isTesting = testing
        nameField.isEnabled = !testing
        targetField.isEnabled = !testing
        testButton.isEnabled = !testing
        if testing {
            addButton.isEnabled = false
        }
    }

    private func setStatus(_ message: String, color: NSColor) {
        statusLabel.stringValue = message
        statusLabel.textColor = color
    }

    private var currentInput: MenuBarHostInput {
        MenuBarHostInput(
            name: nameField.stringValue,
            sshTarget: targetField.stringValue
        )
    }
}
