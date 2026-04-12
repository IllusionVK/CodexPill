import Foundation
import Testing

@testable import CodexPill

struct MenuBarMenuStateTests {
    @Test
    func menuBadgeDisplayNamesHideLocalWhenNoRemoteHostsExist() {
        #expect(menuBadgeDisplayNames(from: ["local"], hasRemoteHosts: false).isEmpty)
        #expect(menuBadgeDisplayNames(from: ["debian-vm", "local"], hasRemoteHosts: true) == ["debian-vm", "local"])
    }

    @Test
    func visibleAndOverflowAccountsRespectConfiguredLimit() {
        let accounts = [
            makeAccount(name: "A"),
            makeAccount(name: "B"),
            makeAccount(name: "C")
        ]

        let state = makeState(inactiveAccounts: accounts, visibleInactiveAccountCount: 2)

        #expect(state.visibleInactiveAccounts.map(\.name) == ["A", "B"])
        #expect(state.overflowInactiveAccounts.map(\.name) == ["C"])
    }

    @Test
    func zeroVisibleCountShowsAllAccountsWithoutOverflow() {
        let accounts = [
            makeAccount(name: "A"),
            makeAccount(name: "B")
        ]

        let state = makeState(inactiveAccounts: accounts, visibleInactiveAccountCount: 0)

        #expect(state.visibleInactiveAccounts.map(\.name) == ["A", "B"])
        #expect(state.overflowInactiveAccounts.isEmpty)
    }

    @Test
    func busyStateDisablesInteractiveActions() {
        let state = makeState(activeAccounts: [], inactiveAccounts: [], isBusy: true)

        #expect(!state.canSaveCurrentAccount)
        #expect(!state.canSignInAnotherAccount)
        #expect(!state.canShowAbout)
    }

    @Test
    func activeSavedAccountDisablesSaveCurrentAccount() {
        let state = makeState(
            activeAccounts: [ActiveObservedAccount(account: makeAccount(name: "Active"), contextBadges: ["local"])],
            inactiveAccounts: [],
            hasLocalActiveSavedAccount: true,
            isBusy: false
        )

        #expect(!state.canSaveCurrentAccount)
        #expect(state.canSignInAnotherAccount)
    }

    @Test
    func statusMessageOnlyShowsWhileBusy() {
        let hidden = makeState(inactiveAccounts: [], isBusy: false, statusMessage: "Refreshing...")
        let shown = makeState(inactiveAccounts: [], isBusy: true, statusMessage: "Refreshing...")

        #expect(!hidden.shouldShowStatusMessage)
        #expect(shown.shouldShowStatusMessage)
    }

    @Test
    func removeAccountsIsAvailableWhenSavedAccountsExist() {
        let state = makeState(
            activeAccounts: [ActiveObservedAccount(account: makeAccount(name: "Active"), contextBadges: ["local"])],
            inactiveAccounts: [makeAccount(name: "Other")],
            hasLocalActiveSavedAccount: true
        )

        #expect(state.canRemoveSavedAccounts)
        #expect(state.canRenameSavedAccounts)
        #expect(state.allSavedAccounts.map(\.name) == ["Active", "Other"])
    }

    @Test
    func saveCurrentAccountIsAllowedWhenThereAreNoSavedAccounts() {
        let state = makeState(activeAccounts: [], inactiveAccounts: [], isBusy: false)

        #expect(state.canSaveCurrentAccount)
        #expect(state.allSavedAccounts.isEmpty)
    }

    private func makeState(
        activeAccounts: [ActiveObservedAccount] = [],
        inactiveAccounts: [CodexAccount],
        hostContexts: [ObservedExecutionContext] = [],
        hasLocalActiveSavedAccount: Bool = false,
        visibleInactiveAccountCount: Int = 2,
        isBusy: Bool = false,
        statusMessage: String = "Ready"
    ) -> MenuBarMenuState {
        MenuBarMenuState(
            activeAccounts: activeAccounts,
            inactiveAccounts: inactiveAccounts,
            savedHosts: [],
            hostContexts: hostContexts,
            hasLocalActiveSavedAccount: hasLocalActiveSavedAccount,
            visibleInactiveAccountCount: visibleInactiveAccountCount,
            visibleInactiveAccountCountOptions: [0, 2, 4],
            refreshIntervalMinutes: 5,
            refreshIntervalOptions: [1, 5, 10],
            statusBarMonochrome: false,
            statusBarIndicatorStyle: .dualArcBadge,
            isBusy: isBusy,
            statusMessage: statusMessage
        )
    }

    private func makeAccount(name: String) -> CodexAccount {
        CodexAccount(
            id: UUID(),
            name: name,
            snapshotFileName: "\(UUID().uuidString).json",
            createdAt: .distantPast,
            updatedAt: .distantPast,
            email: "\(name.lowercased())@example.com",
            planType: nil,
            rateLimits: nil,
            identity: CodexAccountIdentity(
                snapshotFingerprint: UUID().uuidString,
                remoteIdentity: CodexRemoteAccountIdentity(emailAddress: "\(name.lowercased())@example.com")
            )
        )
    }
}
