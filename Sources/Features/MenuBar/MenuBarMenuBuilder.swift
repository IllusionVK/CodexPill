import AppKit
import SwiftUI

struct ActiveObservedAccount: Equatable {
    let account: CodexAccount
    let contextBadges: [String]
}

struct MenuBarMenuState {
    let activeAccounts: [ActiveObservedAccount]
    let inactiveAccounts: [CodexAccount]
    let hostContexts: [ObservedExecutionContext]
    let hasLocalActiveSavedAccount: Bool
    let visibleInactiveAccountCount: Int
    let visibleInactiveAccountCountOptions: [Int]
    let refreshIntervalMinutes: Int
    let refreshIntervalOptions: [Int]
    let statusBarMonochrome: Bool
    let statusBarIndicatorStyle: StatusBarIndicatorStyle
    let isBusy: Bool
    let statusMessage: String

    var canSaveCurrentAccount: Bool {
        !isBusy && !hasLocalActiveSavedAccount
    }

    var canSignInAnotherAccount: Bool {
        !isBusy
    }

    var canShowAbout: Bool {
        !isBusy
    }

    var canRemoveSavedAccounts: Bool {
        !isBusy && allSavedAccounts.count > 0
    }

    var canRenameSavedAccounts: Bool {
        !isBusy && allSavedAccounts.count > 0
    }

    var canAddRemoteHosts: Bool {
        !isBusy
    }

    var allSavedAccounts: [CodexAccount] {
        activeAccounts.map(\.account) + inactiveAccounts
    }

    var visibleInactiveAccounts: [CodexAccount] {
        guard visibleInactiveAccountCount > 0 else { return inactiveAccounts }
        return Array(inactiveAccounts.prefix(visibleInactiveAccountCount))
    }

    var overflowInactiveAccounts: [CodexAccount] {
        guard visibleInactiveAccountCount > 0, inactiveAccounts.count > visibleInactiveAccountCount else { return [] }
        return Array(inactiveAccounts.dropFirst(visibleInactiveAccountCount))
    }

    var shouldShowStatusMessage: Bool {
        guard !statusMessage.isEmpty else { return false }
        return isBusy
    }
}

@MainActor
struct MenuBarMenuBuilder {
    func makeMenu(state: MenuBarMenuState, target: MenuBarCoordinator) -> NSMenu {
        let menu = NSMenu()
        menu.delegate = target

        if !state.activeAccounts.isEmpty {
            menu.addItem(sectionHeaderItem("Active Accounts", bottomPadding: 4))
            for activeAccount in state.activeAccounts {
                menu.addItem(activeAccountItem(for: activeAccount))
            }
        } else {
            menu.addItem(sectionHeaderItem("Active Accounts", bottomPadding: 4))
            menu.addItem(disabledInfoItem("No active observed accounts"))
        }

        if !state.visibleInactiveAccounts.isEmpty {
            menu.addItem(.separator())
            menu.addItem(sectionHeaderItem("Other Saved Accounts", bottomPadding: 4))
            for account in state.visibleInactiveAccounts {
                menu.addItem(inactiveAccountItem(for: account, target: target))
            }
        }

        if !state.overflowInactiveAccounts.isEmpty {
            if state.visibleInactiveAccounts.isEmpty {
                menu.addItem(.separator())
            }
            menu.addItem(moreAccountsMenuItem(accounts: state.overflowInactiveAccounts, target: target))
        }

        menu.addItem(.separator())
        menu.addItem(hostsMenuItem(state: state, target: target))
        menu.addItem(accountsMenuItem(state: state, target: target))
        menu.addItem(refreshIntervalMenuItem(state: state, target: target))
        menu.addItem(statusBarStyleMenuItem(state: state, target: target))
        menu.addItem(actionItem(title: "About", systemImage: "info.circle", action: #selector(MenuBarCoordinator.showAbout), state: state, target: target))

        if state.shouldShowStatusMessage {
            menu.addItem(.separator())
            menu.addItem(disabledInfoItem(state.statusMessage))
        }

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(MenuBarCoordinator.quitApp), keyEquivalent: "q")
        quit.target = target
        menu.addItem(quit)

        return menu
    }

    private func activeAccountItem(for activeAccount: ActiveObservedAccount) -> NSMenuItem {
        let item = NSMenuItem()
        let view = NSHostingView(rootView: ActiveAccountMenuContent(
            account: activeAccount.account,
            contextBadges: activeAccount.contextBadges
        ))
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

    private func inactiveAccountItem(for account: CodexAccount, target: MenuBarCoordinator) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: #selector(MenuBarCoordinator.switchAccount(_:)), keyEquivalent: "")
        item.target = target
        item.representedObject = account.id.uuidString
        item.attributedTitle = inactiveAccountTitle(for: account)
        return item
    }

    private func actionItem(title: String, systemImage: String, action: Selector, state: MenuBarMenuState, target: MenuBarCoordinator) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = target
        item.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: title)
        item.isEnabled = !state.isBusy
        return item
    }

    private func addAccountMenuItem(state: MenuBarMenuState, target: MenuBarCoordinator) -> NSMenuItem {
        let item = NSMenuItem(title: "Add Account", action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "plus.circle", accessibilityDescription: "Add Account")

        let submenu = NSMenu(title: "Add Account")
        let saveCurrent = NSMenuItem(title: "Save Current Account", action: #selector(MenuBarCoordinator.addCurrentAccount), keyEquivalent: "")
        saveCurrent.target = target
        saveCurrent.isEnabled = state.canSaveCurrentAccount
        submenu.addItem(saveCurrent)

        let signInAnother = NSMenuItem(title: "Sign In Another Account…", action: #selector(MenuBarCoordinator.signInAnotherAccount), keyEquivalent: "")
        signInAnother.target = target
        signInAnother.isEnabled = state.canSignInAnotherAccount
        submenu.addItem(signInAnother)

        item.submenu = submenu
        return item
    }

    private func accountsMenuItem(state: MenuBarMenuState, target: MenuBarCoordinator) -> NSMenuItem {
        let item = NSMenuItem(title: "Accounts", action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "person.2.circle", accessibilityDescription: "Accounts")

        let submenu = NSMenu(title: "Accounts")
        submenu.addItem(addAccountMenuItem(state: state, target: target))
        submenu.addItem(renameAccountMenuItem(state: state, target: target))
        submenu.addItem(removeAccountMenuItem(state: state, target: target))
        submenu.addItem(visibleAccountsMenuItem(state: state, target: target))

        item.submenu = submenu
        return item
    }

    private func removeAccountMenuItem(state: MenuBarMenuState, target: MenuBarCoordinator) -> NSMenuItem {
        let item = NSMenuItem(title: "Remove Account", action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Remove Account")
        item.isEnabled = state.canRemoveSavedAccounts

        let submenu = NSMenu(title: "Remove Account")
        for account in state.allSavedAccounts {
            let option = NSMenuItem(
                title: isLocallyActive(account: account, state: state) ? "\(account.name) (Current)" : account.name,
                action: #selector(MenuBarCoordinator.removeAccount(_:)),
                keyEquivalent: ""
            )
            option.target = target
            option.representedObject = account.id.uuidString
            option.isEnabled = state.canRemoveSavedAccounts
            submenu.addItem(option)
        }

        if submenu.items.isEmpty {
            let empty = NSMenuItem(title: "No saved accounts", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            submenu.addItem(empty)
        }

        item.submenu = submenu
        return item
    }

    private func renameAccountMenuItem(state: MenuBarMenuState, target: MenuBarCoordinator) -> NSMenuItem {
        let item = NSMenuItem(title: "Rename Account", action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "pencil", accessibilityDescription: "Rename Account")
        item.isEnabled = state.canRenameSavedAccounts

        let submenu = NSMenu(title: "Rename Account")
        for account in state.allSavedAccounts {
            let option = NSMenuItem(
                title: isLocallyActive(account: account, state: state) ? "\(account.name) (Current)" : account.name,
                action: #selector(MenuBarCoordinator.renameAccount(_:)),
                keyEquivalent: ""
            )
            option.target = target
            option.representedObject = account.id.uuidString
            option.isEnabled = state.canRenameSavedAccounts
            submenu.addItem(option)
        }

        if submenu.items.isEmpty {
            let empty = NSMenuItem(title: "No saved accounts", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            submenu.addItem(empty)
        }

        item.submenu = submenu
        return item
    }

    private func visibleAccountsMenuItem(state: MenuBarMenuState, target: MenuBarCoordinator) -> NSMenuItem {
        let item = NSMenuItem(title: "Visible Other Accounts", action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "line.3.horizontal.decrease.circle", accessibilityDescription: "Visible Other Accounts")

        let submenu = NSMenu(title: "Visible Other Accounts")
        for count in state.visibleInactiveAccountCountOptions {
            let title = count == 0 ? "All" : "\(count)"
            let option = NSMenuItem(title: title, action: #selector(MenuBarCoordinator.selectVisibleInactiveAccountCount(_:)), keyEquivalent: "")
            option.target = target
            option.representedObject = count
            option.state = state.visibleInactiveAccountCount == count ? .on : .off
            submenu.addItem(option)
        }

        item.submenu = submenu
        return item
    }

    private func hostsMenuItem(state: MenuBarMenuState, target: MenuBarCoordinator) -> NSMenuItem {
        let item = NSMenuItem(title: "Hosts", action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "network", accessibilityDescription: "Hosts")

        let submenu = NSMenu(title: "Hosts")
        let addHost = NSMenuItem(title: "Add Host…", action: #selector(MenuBarCoordinator.addRemoteHost), keyEquivalent: "")
        addHost.target = target
        addHost.isEnabled = state.canAddRemoteHosts
        submenu.addItem(addHost)

        if !state.hostContexts.isEmpty {
            submenu.addItem(.separator())
            for context in state.hostContexts {
                let row = NSMenuItem(title: hostTitle(for: context, state: state), action: nil, keyEquivalent: "")
                row.isEnabled = false
                submenu.addItem(row)
            }
        }

        item.submenu = submenu
        return item
    }

    private func moreAccountsMenuItem(accounts: [CodexAccount], target: MenuBarCoordinator) -> NSMenuItem {
        let item = NSMenuItem(title: "More Accounts", action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: "More Accounts")

        let submenu = NSMenu(title: "More Accounts")
        for account in accounts {
            submenu.addItem(inactiveAccountItem(for: account, target: target))
        }

        item.submenu = submenu
        return item
    }

    private func refreshIntervalMenuItem(state: MenuBarMenuState, target: MenuBarCoordinator) -> NSMenuItem {
        let item = NSMenuItem(title: "Refresh Time", action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Refresh Time")

        let submenu = NSMenu(title: "Refresh Time")
        for minutes in state.refreshIntervalOptions {
            let option = NSMenuItem(title: "\(minutes) minutes", action: #selector(MenuBarCoordinator.selectRefreshInterval(_:)), keyEquivalent: "")
            option.target = target
            option.representedObject = minutes
            option.state = state.refreshIntervalMinutes == minutes ? .on : .off
            submenu.addItem(option)
        }

        item.submenu = submenu
        return item
    }

    private func statusBarStyleMenuItem(state: MenuBarMenuState, target: MenuBarCoordinator) -> NSMenuItem {
        let item = NSMenuItem(title: "Status Bar Style", action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "square.2.layers.3d.top.filled", accessibilityDescription: "Status Bar Style")

        let submenu = NSMenu(title: "Status Bar Style")
        let monochrome = NSMenuItem(title: "Monochrome", action: #selector(MenuBarCoordinator.toggleStatusBarMonochrome(_:)), keyEquivalent: "")
        monochrome.target = target
        monochrome.state = state.statusBarMonochrome ? .on : .off
        submenu.addItem(monochrome)
        submenu.addItem(.separator())

        for style in StatusBarIndicatorStyle.allCases {
            let option = NSMenuItem(title: style.menuTitle, action: #selector(MenuBarCoordinator.selectStatusBarStyle(_:)), keyEquivalent: "")
            option.target = target
            option.representedObject = style.rawValue
            option.state = state.statusBarIndicatorStyle == style ? .on : .off
            submenu.addItem(option)
        }

        item.submenu = submenu
        return item
    }

    private func hostTitle(for context: ObservedExecutionContext, state: MenuBarMenuState) -> String {
        switch context.status {
        case .matched(let accountID):
            let accountName = state.allSavedAccounts.first(where: { $0.id == accountID })?.name ?? "Unknown"
            return "\(context.displayName) -> \(accountName)"
        case .unmatched(let summary):
            if let email = summary.email {
                return "\(context.displayName) -> Unmatched (\(email))"
            }
            return "\(context.displayName) -> Unmatched"
        case .unavailable:
            return "\(context.displayName) -> Unavailable"
        case .loading:
            return "\(context.displayName) -> Loading"
        }
    }

    private func isLocallyActive(account: CodexAccount, state: MenuBarMenuState) -> Bool {
        state.activeAccounts.contains { $0.account.id == account.id && $0.contextBadges.contains("local") }
    }
}

private struct ActiveAccountMenuContent: View {
    let account: CodexAccount
    let contextBadges: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(account.name)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text(account.planType?.capitalized ?? "Unknown")
                    .foregroundStyle(.secondary)
            }

            if !contextBadges.isEmpty {
                HStack(spacing: 6) {
                    ForEach(contextBadges, id: \.self) { badge in
                        Text(badge)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.secondary.opacity(0.14)))
                    }
                    Spacer(minLength: 0)
                }
            }

            if let email = account.email {
                HStack(alignment: .firstTextBaseline) {
                    Text("Updated \(RelativeDateTimeFormatter().localizedString(for: account.lastRemoteRefreshAt, relativeTo: .now))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, -2)
            }

            ActiveLimitRow(title: "Session", window: account.rateLimits?.primary)
            ActiveLimitRow(title: "Weekly", window: account.rateLimits?.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.top, 4)
        .padding(.bottom, 4)
        .frame(width: 340, alignment: .leading)
    }
}

private struct ActiveLimitRow: View {
    let title: String
    let window: CodexRateLimitWindow?

    var body: some View {
        let displayedUsedPercent = window?.displayedUsedPercent() ?? 0
        let usageText = window.map { "\($0.displayedUsedPercent())% used" } ?? "--"

        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            ProgressView(value: Double(displayedUsedPercent), total: 100)
            HStack {
                Text(usageText)
                    .monospacedDigit()
                Spacer()
                if let window, let resetStatus = resetStatusText(for: window) {
                    Text(resetStatus)
                        .foregroundStyle(.secondary)
                } else if window == nil {
                    Text("Unavailable")
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

private func inactiveAccountLine(title: String, window: CodexRateLimitWindow?) -> String {
    let usedText = window.map { "\($0.displayedUsedPercent())% used" } ?? "--"
    guard let window, let resetStatus = resetStatusText(for: window) else {
        return "\(title): \(usedText)"
    }
    return "\(title): \(usedText), \(resetStatus)"
}

private func resetStatusText(for window: CodexRateLimitWindow) -> String? {
    guard let resetsAt = window.resetsAt else { return nil }

    let now = Date()
    if resetsAt <= now {
        return "resets now"
    }

    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return "resets \(formatter.localizedString(for: resetsAt, relativeTo: now))"
}
