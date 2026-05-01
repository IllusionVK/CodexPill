import Foundation

struct ActiveAccountCard: Equatable {
    let account: CodexAccount
    let locations: [String]
    let showsUpdatedTime: Bool
}

struct ActiveAccountsProjection {
    let activeAccount: CodexAccount?
    let connectedRemoteHosts: [RemoteHostMenuState]

    var activeAccountCards: [ActiveAccountCard] {
        var cards: [ActiveAccountCard] = []
        let verifiedRemoteHosts = connectedRemoteHosts.filter(\.isVerified)
        let localRemoteHosts = verifiedRemoteHosts.filter { remoteHost in
            guard let activeAccount,
                  let remoteAccount = remoteHost.activeAccount else {
                return false
            }
            return remoteAccount.matchesSameAccount(as: activeAccount)
        }
        let remoteHostsNotRepresentedByLocal = verifiedRemoteHosts.filter { remoteHost in
            guard let activeAccount,
                  let remoteAccount = remoteHost.activeAccount else {
                return true
            }
            return !remoteAccount.matchesSameAccount(as: activeAccount)
        }

        if let activeAccount {
            let locations = localRemoteHosts.isEmpty && remoteHostsNotRepresentedByLocal.isEmpty
                ? []
                : ["This Mac"] + localRemoteHosts.map(\.name)
            cards.append(
                ActiveAccountCard(
                    account: activeAccount,
                    locations: locations,
                    showsUpdatedTime: locations.isEmpty
                )
            )
        }

        for group in groupedRemoteActiveHosts(remoteHostsNotRepresentedByLocal) {
            guard let displayAccount = group.first?.activeAccount else { continue }
            cards.append(
                ActiveAccountCard(
                    account: displayAccount,
                    locations: group.map(\.name),
                    showsUpdatedTime: false
                )
            )
        }

        return cards
    }

    var sectionTitle: String {
        activeAccountCards.count == 1 ? "Active Account" : "Active Accounts"
    }

    private func groupedRemoteActiveHosts(_ remoteHosts: [RemoteHostMenuState]) -> [[RemoteHostMenuState]] {
        remoteHosts.reduce(into: [[RemoteHostMenuState]]()) { groups, remoteHost in
            guard let remoteAccount = remoteHost.activeAccount else { return }
            if let index = groups.firstIndex(where: { group in
                group.contains { existingHost in
                    existingHost.activeAccount?.matchesSameAccount(as: remoteAccount) == true
                }
            }) {
                groups[index].append(remoteHost)
            } else {
                groups.append([remoteHost])
            }
        }
    }
}

extension CodexAccount {
    func matchesSameAccount(as other: CodexAccount) -> Bool {
        id == other.id ||
            hasSameStrongAccountIdentity(as: other) ||
            hasSameDisplayAccountIdentity(as: other)
    }

    private func hasSameStrongAccountIdentity(as other: CodexAccount) -> Bool {
        if let stableAccountID = normalizedIdentityValue(identity.stableAccountID),
           stableAccountID == normalizedIdentityValue(other.identity.stableAccountID) {
            return true
        }

        if let snapshotFingerprint = normalizedIdentityValue(identity.snapshotFingerprint),
           snapshotFingerprint == normalizedIdentityValue(other.identity.snapshotFingerprint) {
            return true
        }

        if let authPrincipalIdentity = identity.authPrincipalIdentity,
           authPrincipalIdentity.isMeaningful,
           authPrincipalIdentity == other.identity.authPrincipalIdentity {
            return true
        }

        if let workspaceIdentity = identity.workspaceIdentity,
           workspaceIdentity.isMeaningful,
           workspaceIdentity == other.identity.workspaceIdentity {
            return true
        }

        return false
    }

    private func hasSameDisplayAccountIdentity(as other: CodexAccount) -> Bool {
        normalizedInspectableEmail != nil
            && normalizedInspectableEmail == other.normalizedInspectableEmail
            && normalizedCodexPlanType(effectivePlanType) == normalizedCodexPlanType(other.effectivePlanType)
            && normalizedAccountName == other.normalizedAccountName
    }

    private var normalizedInspectableEmail: String? {
        guard let email else { return nil }
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.isEmpty ? nil : normalized
    }

    private var normalizedAccountName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func normalizedIdentityValue(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized?.isEmpty == false ? normalized : nil
    }
}
