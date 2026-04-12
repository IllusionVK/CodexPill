import SwiftUI

struct MenuBarValidationSnapshot: Codable, Equatable {
    struct Section: Codable, Equatable {
        let title: String
        let items: [String]
    }

    let sections: [Section]
    let statusMessage: String?
}

@MainActor
enum MenuBarValidationSupport {
    static func makeSnapshot(state: MenuBarMenuState, now: Date = .now) -> MenuBarValidationSnapshot {
        var sections: [MenuBarValidationSnapshot.Section] = []

        let activeAccountItems: [String]
        if !state.activeAccounts.isEmpty {
            activeAccountItems = state.activeAccounts.map {
                accountSummary(for: $0.account, badges: $0.contextBadges, now: now)
            }
        } else {
            activeAccountItems = ["No active observed accounts"]
        }
        sections.append(.init(title: "Active Accounts", items: activeAccountItems))

        if !state.visibleInactiveAccounts.isEmpty {
            sections.append(.init(
                title: "Other Saved Accounts",
                items: state.visibleInactiveAccounts.map { accountSummary(for: $0, now: now) }
            ))
        }

        if !state.overflowInactiveAccounts.isEmpty {
            sections.append(.init(
                title: "More Accounts",
                items: state.overflowInactiveAccounts.map { accountSummary(for: $0, now: now) }
            ))
        }

        sections.append(.init(
            title: "Accounts",
            items: [
                state.canSaveCurrentAccount ? "Save Current Account" : "Save Current Account (disabled)",
                state.canSignInAnotherAccount ? "Sign In Another Account…" : "Sign In Another Account… (disabled)",
                "Rename Account",
                "Remove Account",
                "Visible Other Accounts: \(state.visibleInactiveAccountCount == 0 ? "All" : "\(state.visibleInactiveAccountCount)")"
            ]
        ))

        sections.append(.init(
            title: "Hosts",
            items: ["Add Host…"] + state.hostContexts.map { hostSummary(for: $0, state: state) }
        ))

        sections.append(.init(
            title: "Preferences",
            items: [
                "Refresh Time: \(state.refreshIntervalMinutes) minutes",
                "Status Bar Style: \(state.statusBarIndicatorStyle.menuTitle)",
                state.statusBarMonochrome ? "Monochrome: On" : "Monochrome: Off",
                state.canShowAbout ? "About" : "About (disabled)"
            ]
        ))

        return MenuBarValidationSnapshot(
            sections: sections,
            statusMessage: state.shouldShowStatusMessage ? state.statusMessage : nil
        )
    }

    static func makeHostedValidationView(state: MenuBarMenuState, now: Date = .now) -> some View {
        let snapshot = makeSnapshot(state: state, now: now)

        return VStack(alignment: .leading, spacing: 16) {
            ForEach(snapshot.sections, id: \.title) { section in
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    ForEach(section.items, id: \.self) { item in
                        Text(item)
                            .font(.system(size: 13))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 3)
                    }
                }
            }

            if let statusMessage = snapshot.statusMessage {
                VStack(alignment: .leading, spacing: 6) {
                    Divider()
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .frame(width: 360, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private static func accountSummary(for account: CodexAccount, badges: [String] = [], now: Date) -> String {
        let plan = menuPlanDisplayName(account.planType)
        let email = account.email ?? "No email"
        let session = usageLine(title: "Session", window: account.rateLimits?.primary, now: now)
        let weekly = usageLine(title: "Weekly", window: account.rateLimits?.secondary, now: now)
        let badgeText = badges.isEmpty ? "" : " [\(badges.joined(separator: ", "))]"
        return "\(account.name) • \(plan)\(badgeText) • \(email) • \(session) • \(weekly)"
    }

    private static func hostSummary(for context: ObservedExecutionContext, state: MenuBarMenuState) -> String {
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

    private static func usageLine(title: String, window: CodexRateLimitWindow?, now: Date) -> String {
        let percentText = window.map { "\($0.displayedUsedPercent(at: now))% used" } ?? "--"
        guard let window, let resetsAt = window.resetsAt, resetsAt > now else {
            return "\(title): \(percentText)"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "\(title): \(percentText), Resets \(formatter.localizedString(for: resetsAt, relativeTo: now))"
    }
}
