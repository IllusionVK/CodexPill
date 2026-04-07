import AppKit
import OSLog
import SwiftUI

private let appDelegateLogger = Logger(subsystem: "com.raphhgg.codex-switchboard", category: "AppDelegate")

@MainActor
final class CodexPillAppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var store: MenuBarStore!
    private let settings = AppSettings.shared
    private let iconRenderer = StatusBarIconRenderer()
    private let cliProcessInspector = CodexCLIProcessInspector()
    private var statusItem: NSStatusItem!
    private var storeObserver: NSObjectProtocol?
    private var settingsObserver: NSObjectProtocol?
    private var autoRefreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let repository = try! AccountRepository()
        let authService = CodexAuthSnapshotService(repository: repository)
        let controller = CodexAppController()
        let appServerClient = CodexAppServerClient()
        store = MenuBarStore(
            repository: repository,
            authService: authService,
            appController: controller,
            appServerClient: appServerClient
        )

        setupStatusItem()
        storeObserver = NotificationCenter.default.addObserver(
            forName: .codexSwitchboardStoreDidChange,
            object: store,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateStatusItemAppearance()
                self?.rebuildMenu()
                self?.presentPendingErrorIfNeeded()
            }
        }
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .codexSwitchboardSettingsDidChange,
            object: settings,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateStatusItemAppearance()
                self?.scheduleAutoRefresh()
                self?.rebuildMenu()
            }
        }

        store.load()
        scheduleAutoRefresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let storeObserver {
            NotificationCenter.default.removeObserver(storeObserver)
        }
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
        autoRefreshTimer?.invalidate()
    }

    func menuWillOpen(_ menu: NSMenu) {
        store.refreshActiveAccount()
        rebuildMenu()
        Task { await store.completePendingSignedInAccountIfNeeded() }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusItemAppearance()
        statusItem.button?.imagePosition = .imageOnly
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.delegate = self

        if let activeAccount = store.activeAccount {
            menu.addItem(sectionHeaderItem("Current Account", bottomPadding: 4))
            menu.addItem(activeAccountItem(for: activeAccount))
        } else {
            menu.addItem(sectionHeaderItem("Current Account", bottomPadding: 4))
            menu.addItem(disabledInfoItem("No active saved account"))
            menu.addItem(disabledInfoItem("Use Add Current Account… while logged into Codex."))
        }

        let visibleInactiveAccounts = visibleInactiveAccounts()
        let overflowInactiveAccounts = overflowInactiveAccounts()

        if !visibleInactiveAccounts.isEmpty {
            menu.addItem(.separator())
            menu.addItem(sectionHeaderItem("Other Accounts", bottomPadding: 4))
            for account in visibleInactiveAccounts {
                menu.addItem(inactiveAccountItem(for: account))
            }
        }

        if !overflowInactiveAccounts.isEmpty {
            if visibleInactiveAccounts.isEmpty {
                menu.addItem(.separator())
            }
            menu.addItem(moreAccountsMenuItem(accounts: overflowInactiveAccounts))
        }

        menu.addItem(.separator())
        menu.addItem(addAccountMenuItem())
        menu.addItem(visibleAccountsMenuItem())
        menu.addItem(refreshIntervalMenuItem())
        menu.addItem(statusBarStyleMenuItem())
        menu.addItem(makeActionItem(
            title: "About",
            systemImage: "info.circle",
            action: #selector(showAbout)
        ))

        if shouldShowStatusMessage {
            menu.addItem(.separator())
            menu.addItem(disabledInfoItem(store.statusMessage))
        }

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func activeAccountItem(for account: CodexAccount) -> NSMenuItem {
        let item = NSMenuItem()
        let view = NSHostingView(rootView: ActiveAccountMenuContent(account: account))
        view.frame = NSRect(x: 0, y: 0, width: 340, height: 1)
        view.layoutSubtreeIfNeeded()
        let fittingHeight = max(1, view.fittingSize.height)
        view.frame = NSRect(x: 0, y: 0, width: 340, height: fittingHeight)
        item.view = view
        return item
    }

    private func sectionHeaderItem(_ title: String, bottomPadding: CGFloat) -> NSMenuItem {
        let item = NSMenuItem()
        let view = NSHostingView(rootView: SectionHeaderLabel(title: title, bottomPadding: bottomPadding))
        view.frame = NSRect(x: 0, y: 0, width: 320, height: 18 + bottomPadding)
        item.view = view
        return item
    }

    private func disabledInfoItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func inactiveAccountItem(for account: CodexAccount) -> NSMenuItem {
        let item = NSMenuItem(
            title: "",
            action: #selector(switchAccount(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.representedObject = account.id.uuidString
        item.attributedTitle = inactiveAccountTitle(for: account)
        return item
    }

    private func makeActionItem(title: String, systemImage: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: title)
        item.isEnabled = !store.isBusy
        return item
    }

    private func addAccountMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Add Account", action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "plus.circle", accessibilityDescription: "Add Account")

        let submenu = NSMenu(title: "Add Account")
        let currentAccountAlreadySaved = store.activeAccount != nil

        let saveCurrent = NSMenuItem(
            title: "Save Current Account",
            action: #selector(addCurrentAccount),
            keyEquivalent: ""
        )
        saveCurrent.target = self
        saveCurrent.isEnabled = !store.isBusy && !currentAccountAlreadySaved
        submenu.addItem(saveCurrent)

        let signInAnother = NSMenuItem(
            title: "Sign In Another Account…",
            action: #selector(signInAnotherAccount),
            keyEquivalent: ""
        )
        signInAnother.target = self
        signInAnother.isEnabled = !store.isBusy
        submenu.addItem(signInAnother)

        item.submenu = submenu
        return item
    }

    private func visibleAccountsMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Visible Other Accounts", action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "line.3.horizontal.decrease.circle", accessibilityDescription: "Visible Other Accounts")

        let submenu = NSMenu(title: "Visible Other Accounts")
        for count in settings.visibleInactiveAccountCountOptions {
            let title = count == 0 ? "All" : "\(count)"
            let option = NSMenuItem(
                title: title,
                action: #selector(selectVisibleInactiveAccountCount(_:)),
                keyEquivalent: ""
            )
            option.target = self
            option.representedObject = count
            option.state = settings.visibleInactiveAccountCount == count ? .on : .off
            submenu.addItem(option)
        }

        item.submenu = submenu
        return item
    }

    private func moreAccountsMenuItem(accounts: [CodexAccount]) -> NSMenuItem {
        let item = NSMenuItem(title: "More Accounts", action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: "More Accounts")

        let submenu = NSMenu(title: "More Accounts")
        for account in accounts {
            submenu.addItem(inactiveAccountItem(for: account))
        }

        item.submenu = submenu
        return item
    }

    private func refreshIntervalMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Refresh Time", action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Refresh Time")

        let submenu = NSMenu(title: "Refresh Time")
        for minutes in settings.refreshIntervalOptions {
            let option = NSMenuItem(
                title: "\(minutes) minutes",
                action: #selector(selectRefreshInterval(_:)),
                keyEquivalent: ""
            )
            option.target = self
            option.representedObject = minutes
            option.state = settings.refreshIntervalMinutes == minutes ? .on : .off
            submenu.addItem(option)
        }

        item.submenu = submenu
        return item
    }

    private func statusBarStyleMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Status Bar Style", action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "square.2.layers.3d.top.filled", accessibilityDescription: "Status Bar Style")

        let submenu = NSMenu(title: "Status Bar Style")
        let monochrome = NSMenuItem(
            title: "Monochrome",
            action: #selector(toggleStatusBarMonochrome(_:)),
            keyEquivalent: ""
        )
        monochrome.target = self
        monochrome.state = settings.statusBarMonochrome ? .on : .off
        submenu.addItem(monochrome)
        submenu.addItem(.separator())

        for style in StatusBarIndicatorStyle.allCases {
            let option = NSMenuItem(
                title: style.menuTitle,
                action: #selector(selectStatusBarStyle(_:)),
                keyEquivalent: ""
            )
            option.target = self
            option.representedObject = style.rawValue
            option.state = settings.statusBarIndicatorStyle == style ? .on : .off
            submenu.addItem(option)
        }

        item.submenu = submenu
        return item
    }

    private var shouldShowStatusMessage: Bool {
        guard !store.statusMessage.isEmpty else { return false }
        return store.isBusy
    }

    private func inactiveAccountTitle(for account: CodexAccount) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        paragraph.paragraphSpacing = 4

        let title = NSMutableAttributedString(
            string: "\(account.name)\n",
            attributes: [
                .font: NSFont.menuFont(ofSize: 13),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraph
            ]
        )

        title.append(NSAttributedString(
            string: inactiveAccountLine(title: "Session", window: account.rateLimits?.primary) + "\n",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: paragraph
            ]
        ))

        title.append(NSAttributedString(
            string: inactiveAccountLine(title: "Weekly", window: account.rateLimits?.secondary),
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: paragraph
            ]
        ))

        return title
    }

    private func scheduleAutoRefresh() {
        autoRefreshTimer?.invalidate()
        let interval = TimeInterval(settings.refreshIntervalMinutes * 60)
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performScheduledRefresh()
            }
        }
    }

    private func updateStatusItemAppearance() {
        let primary = store?.activeAccount?.rateLimits?.primary?.usedPercent
        let secondary = store?.activeAccount?.rateLimits?.secondary?.usedPercent
        statusItem.button?.image = iconRenderer.makeImage(
            style: settings.statusBarIndicatorStyle,
            primaryPercent: primary,
            secondaryPercent: secondary,
            monochrome: settings.statusBarMonochrome
        )
        statusItem.button?.toolTip = statusItemTooltip(primary: primary, secondary: secondary)
    }

    private func statusItemTooltip(primary: Int?, secondary: Int?) -> String {
        let session = primary.map { "Session \($0)%" } ?? "Session --"
        let weekly = secondary.map { "Weekly \($0)%" } ?? "Weekly --"
        return "CodexPill\n\(session)\n\(weekly)"
    }

    private func performScheduledRefresh() {
        guard !store.isBusy else { return }
        Task {
            if let activeAccount = store.activeAccount {
                await store.refreshAccountData(for: activeAccount)
            }
        }
    }

    @objc
    private func addCurrentAccount() {
        let nameField = NSTextField(string: "")
        nameField.placeholderString = store.activeAccount?.email ?? "Personal 1"

        let alert = NSAlert()
        alert.messageText = "Save current account"
        alert.informativeText = "Choose a label for this saved account. Use distinct names if multiple accounts share the same email."
        alert.alertStyle = .informational
        alert.accessoryView = textFieldAccessoryView(title: "Account Name", field: nameField)
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Task { await store.saveCurrentAccountSnapshot(named: nameField.stringValue) }
    }

    @objc
    private func signInAnotherAccount() {
        appDelegateLogger.log("signInAnotherAccount action invoked")
        let runningCLISessions = cliProcessInspector.runningCLISessionCount()
        appDelegateLogger.log("Running CLI sessions before sign-in-another: \(runningCLISessions, privacy: .public)")
        let nameField = NSTextField(string: "")
        nameField.placeholderString = "Business 2"
        let alert = NSAlert()
        alert.messageText = "Sign in another account?"
        alert.informativeText = signInAnotherInformativeText(runningCLISessions: runningCLISessions)
        alert.alertStyle = .informational
        alert.accessoryView = textFieldAccessoryView(title: "Saved Account Name", field: nameField)
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")
        appDelegateLogger.log("Presenting sign-in-another confirmation alert")

        let response = alert.runModal()
        appDelegateLogger.log("Sign-in-another alert response: \(response.rawValue, privacy: .public)")
        guard response == .alertFirstButtonReturn else {
            appDelegateLogger.log("Sign-in-another flow cancelled from alert")
            return
        }

        appDelegateLogger.log("Dispatching sign-in-another task to store")
        Task { await store.startSignInAnotherAccountFlow(named: nameField.stringValue) }
    }

    @objc
    private func selectRefreshInterval(_ sender: NSMenuItem) {
        guard let minutes = sender.representedObject as? Int else { return }
        settings.refreshIntervalMinutes = minutes
    }

    @objc
    private func selectVisibleInactiveAccountCount(_ sender: NSMenuItem) {
        guard let count = sender.representedObject as? Int else { return }
        settings.visibleInactiveAccountCount = count
    }

    @objc
    private func selectStatusBarStyle(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let style = StatusBarIndicatorStyle(rawValue: rawValue)
        else {
            return
        }
        settings.statusBarIndicatorStyle = style
    }

    @objc
    private func toggleStatusBarMonochrome(_ sender: NSMenuItem) {
        settings.statusBarMonochrome.toggle()
    }

    @objc
    private func switchAccount(_ sender: NSMenuItem) {
        guard
            let idString = sender.representedObject as? String,
            let id = UUID(uuidString: idString),
            let account = store.accounts.first(where: { $0.id == id })
        else {
            return
        }

        let runningCLISessions = cliProcessInspector.runningCLISessionCount()
        let alert = NSAlert()
        alert.messageText = "Switch account?"
        alert.informativeText = switchInformativeText(for: account.name, runningCLISessions: runningCLISessions)
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Switch")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        Task { await store.switchToAccount(account) }
    }

    @objc
    private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "About CodexPill"
        alert.informativeText = """
        CodexPill
        Version 0.1

        A macOS menubar utility to switch Codex accounts and monitor active account limits.

        Developed by Raphael Grau.
        """
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc
    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func presentPendingErrorIfNeeded() {
        guard let message = store.consumePendingErrorMessage() else { return }
        let alert = NSAlert()
        alert.messageText = "CodexPill Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func switchInformativeText(for accountName: String, runningCLISessions: Int) -> String {
        var lines = [
            "This will switch the local Codex account to \(accountName) and restart Codex."
        ]

        if runningCLISessions > 0 {
            let sessionText = runningCLISessions == 1 ? "1 running Codex CLI session was" : "\(runningCLISessions) running Codex CLI sessions were"
            lines.append("\(sessionText) detected. Existing CLI sessions may continue using the previous account until they are restarted.")
        }

        return lines.joined(separator: " ")
    }

    private func signInAnotherInformativeText(runningCLISessions: Int) -> String {
        var lines = [
            "This will sign Codex out, restart the app, and let you log into another account. Save the current account first if you want to keep it."
        ]

        if runningCLISessions > 0 {
            let sessionText = runningCLISessions == 1 ? "1 running Codex CLI session was" : "\(runningCLISessions) running Codex CLI sessions were"
            lines.append("\(sessionText) detected. Existing CLI sessions may continue using the previous account until they are restarted.")
        }

        return lines.joined(separator: " ")
    }

    private func visibleInactiveAccounts() -> [CodexAccount] {
        let sortedAccounts = store.sortedInactiveAccounts
        let limit = settings.visibleInactiveAccountCount
        guard limit > 0 else { return sortedAccounts }
        return Array(sortedAccounts.prefix(limit))
    }

    private func overflowInactiveAccounts() -> [CodexAccount] {
        let sortedAccounts = store.sortedInactiveAccounts
        let limit = settings.visibleInactiveAccountCount
        guard limit > 0, sortedAccounts.count > limit else { return [] }
        return Array(sortedAccounts.dropFirst(limit))
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

    private func configureAlertTextField(_ field: NSTextField) {
        field.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            field.widthAnchor.constraint(equalToConstant: 320),
            field.heightAnchor.constraint(equalToConstant: 26)
        ])
    }
}

private struct ActiveAccountMenuContent: View {
    let account: CodexAccount

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(account.name)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text(account.planType?.capitalized ?? "Unknown")
                    .foregroundStyle(.secondary)
            }

            if let email = account.email {
                HStack(alignment: .firstTextBaseline) {
                    if let fetchedAt = account.rateLimits?.fetchedAt {
                        Text("Updated \(RelativeDateTimeFormatter().localizedString(for: fetchedAt, relativeTo: .now))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, -2)
            }

            if let primary = account.rateLimits?.primary {
                ActiveLimitRow(title: "Session", window: primary)
            }

            if let secondary = account.rateLimits?.secondary {
                ActiveLimitRow(title: "Weekly", window: secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 4)
        .padding(.bottom, 4)
        .frame(width: 340, alignment: .leading)
    }
}

private struct ActiveLimitRow: View {
    let title: String
    let window: CodexRateLimitWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            ProgressView(value: Double(window.usedPercent), total: 100)
            HStack {
                Text("\(window.usedPercent)% used")
                    .monospacedDigit()
                Spacer()
                if let resetStatus = resetStatusText(for: window) {
                    Text(resetStatus)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
        }
    }
}

private struct SectionHeaderLabel: View {
    let title: String
    let bottomPadding: CGFloat

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.top, 2)
            .padding(.bottom, bottomPadding)
    }
}

private func inactiveAccountLine(title: String, window: CodexRateLimitWindow?) -> String {
    let percentText = window.map { "\($0.usedPercent)% used" } ?? "--"
    guard let window, window.usedPercent > 0 else {
        return "\(title): \(percentText)"
    }
    guard let resetStatus = resetStatusText(for: window) else {
        return "\(title): \(percentText)"
    }
    return "\(title): \(percentText) • \(resetStatus)"
}

private func resetStatusText(for window: CodexRateLimitWindow, now: Date = .now) -> String? {
    guard let resetsAt = window.resetsAt, resetsAt > now else {
        return nil
    }

    return "Resets \(shortResetText(for: resetsAt, relativeTo: now))"
}

private func shortResetText(for date: Date, relativeTo now: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: now)
}
