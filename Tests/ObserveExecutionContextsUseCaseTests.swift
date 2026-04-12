import Foundation
import Testing

@testable import CodexPill

struct ObserveExecutionContextsUseCaseTests {
    @Test
    func runBuildsLocalAndRemoteMatchedContexts() async throws {
        let businessOne = makeAccount(
            name: "Business 1",
            stableAccountID: "acct-team",
            subject: "auth0|business-1",
            userID: "user-business-1"
        )
        let businessTwo = makeAccount(
            name: "Business 2",
            stableAccountID: "acct-team",
            subject: "auth0|business-2",
            userID: "user-business-2"
        )
        let observer = RemoteHostObserverStub(results: [
            "debian-vm": .matched(
                RemoteHostObservation(
                    host: RemoteHostConfig(id: UUID(), name: "debian-vm", sshAlias: "debian-vm"),
                    liveIdentity: LiveCodexAccountIdentity(
                        stableAccountID: "acct-team",
                        authPrincipalIdentity: CodexAuthPrincipalIdentity(
                            subject: "auth0|business-2",
                            chatGPTUserID: "user-business-2"
                        ),
                        workspaceIdentity: nil,
                        snapshotFingerprint: nil
                    ),
                    remoteIdentity: CodexRemoteAccountIdentity(emailAddress: "raphaelgrau@gmail.com"),
                    email: "raphaelgrau@gmail.com",
                    planType: "team"
                )
            )
        ])
        let useCase = ObserveExecutionContextsUseCase(
            remoteObserver: observer,
            identityResolver: makeResolver(
                stableAccountID: "acct-team",
                subject: "auth0|business-1",
                userID: "user-business-1"
            )
        )
        let host = RemoteHostConfig(id: UUID(), name: "debian-vm", sshAlias: "debian-vm")

        let contexts = await useCase.run(
            hosts: [host],
            accounts: [businessOne, businessTwo]
        )

        #expect(contexts.count == 2)
        #expect(contexts[0].displayName == "local")
        #expect(contexts[0].status == .matched(accountID: businessOne.id))
        #expect(contexts[1].displayName == "debian-vm")
        #expect(contexts[1].status == .matched(accountID: businessTwo.id))
    }

    @Test
    func runMarksUnavailableHostsExplicitly() async {
        let observer = RemoteHostObserverStub(results: [
            "debian-vm": .unavailable("SSH failed")
        ])
        let useCase = ObserveExecutionContextsUseCase(
            remoteObserver: observer,
            identityResolver: makeResolver(stableAccountID: nil, subject: nil, userID: nil)
        )
        let host = RemoteHostConfig(id: UUID(), name: "debian-vm", sshAlias: "debian-vm")

        let contexts = await useCase.run(hosts: [host], accounts: [])

        #expect(contexts.count == 1)
        #expect(contexts[0].displayName == "debian-vm")
        #expect(contexts[0].status == .unavailable(message: "SSH failed"))
    }

    private func makeAccount(
        name: String,
        stableAccountID: String,
        subject: String,
        userID: String
    ) -> CodexAccount {
        CodexAccount(
            id: UUID(),
            name: name,
            snapshotFileName: "\(UUID().uuidString).json",
            createdAt: .distantPast,
            updatedAt: .distantPast,
            email: "\(name.lowercased())@example.com",
            planType: "team",
            rateLimits: nil,
            identity: CodexAccountIdentity(
                stableAccountID: stableAccountID,
                authPrincipalIdentity: CodexAuthPrincipalIdentity(
                    subject: subject,
                    chatGPTUserID: userID
                ),
                snapshotFingerprint: UUID().uuidString,
                remoteIdentity: CodexRemoteAccountIdentity(emailAddress: "\(name.lowercased())@example.com")
            )
        )
    }

    private func makeResolver(
        stableAccountID: String?,
        subject: String?,
        userID: String?
    ) -> SavedAccountIdentityResolver {
        SavedAccountIdentityResolver(
            liveIdentityReader: FixedIdentityReader(
                identity: LiveCodexAccountIdentity(
                    stableAccountID: stableAccountID,
                    authPrincipalIdentity: CodexAuthPrincipalIdentity(
                        subject: subject,
                        chatGPTUserID: userID
                    ),
                    workspaceIdentity: nil,
                    snapshotFingerprint: nil
                )
            ),
            storedAccountReconciler: ObserveContextsReconcilePassthrough()
        )
    }
}

private final class RemoteHostObserverStub: RemoteHostObserving {
    enum Result {
        case matched(RemoteHostObservation)
        case unavailable(String)
    }

    let results: [String: Result]

    init(results: [String: Result]) {
        self.results = results
    }

    func observe(host: RemoteHostConfig) async -> RemoteHostObservationResult {
        switch results[host.sshAlias] {
        case .matched(let observation):
            return .success(observation)
        case .unavailable(let message):
            return .failure(message)
        case .none:
            return .failure("Missing stub")
        }
    }
}

private struct ObserveContextsReconcilePassthrough: StoredAccountIdentityReconciling {
    func reconcileStoredAccountIdentities(_ accounts: [CodexAccount]) -> [CodexAccount] {
        accounts
    }
}

private struct FixedIdentityReader: LiveCodexAccountIdentityReading {
    let identity: LiveCodexAccountIdentity

    func readCurrentLiveAccountIdentity() -> LiveCodexAccountIdentity {
        identity
    }
}
