import Foundation

protocol RemoteHostObserving {
    func observe(host: RemoteHostConfig) async -> RemoteHostObservationResult
}

struct ObserveExecutionContextsUseCase {
    private let remoteObserver: RemoteHostObserving
    private let identityResolver: SavedAccountIdentityResolver

    init(
        remoteObserver: RemoteHostObserving,
        identityResolver: SavedAccountIdentityResolver
    ) {
        self.remoteObserver = remoteObserver
        self.identityResolver = identityResolver
    }

    func run(
        hosts: [RemoteHostConfig],
        accounts: [CodexAccount]
    ) async -> [ObservedExecutionContext] {
        var contexts: [ObservedExecutionContext] = []

        if let localAccountID = identityResolver.resolveCurrentAccountID(accounts: accounts) {
            contexts.append(
                ObservedExecutionContext(
                    id: "local",
                    kind: .local,
                    displayName: "local",
                    status: .matched(accountID: localAccountID),
                    lastObservedAt: .now
                )
            )
        }

        for host in hosts.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) {
            let result = await remoteObserver.observe(host: host)
            let context = makeRemoteContext(result: result, host: host, accounts: accounts)
            contexts.append(context)
        }

        return contexts
    }

    private func makeRemoteContext(
        result: RemoteHostObservationResult,
        host: RemoteHostConfig,
        accounts: [CodexAccount]
    ) -> ObservedExecutionContext {
        switch result {
        case .failure(let message):
            return ObservedExecutionContext(
                id: "host-\(host.id.uuidString)",
                kind: .sshHost(hostID: host.id),
                displayName: host.name,
                status: .unavailable(message: message),
                lastObservedAt: .now
            )
        case .success(let observation):
            let matchedAccountID = identityResolver.resolve(
                liveIdentity: observation.liveIdentity,
                accounts: accounts,
                liveRemoteIdentity: observation.remoteIdentity
            ).matchedAccountID

            let status: ObservedExecutionContext.Status
            if let matchedAccountID {
                status = .matched(accountID: matchedAccountID)
            } else {
                status = .unmatched(
                    RemoteObservedIdentitySummary(
                        email: observation.email,
                        planType: observation.planType
                    )
                )
            }

            return ObservedExecutionContext(
                id: "host-\(host.id.uuidString)",
                kind: .sshHost(hostID: host.id),
                displayName: host.name,
                status: status,
                lastObservedAt: .now
            )
        }
    }
}
