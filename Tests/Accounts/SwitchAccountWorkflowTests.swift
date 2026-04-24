import Foundation
import Testing

@testable import CodexPill

struct SwitchAccountWorkflowTests {
    @Test
    func runActivatesPersistsRelaunchesAndReturnsMatchedAccount() async throws {
        let target = makeAccount(name: "Target", fingerprint: "live-fingerprint")
        let other = makeAccount(name: "Other", fingerprint: "other-fingerprint")

        let auth = AuthSpy(currentFingerprint: "live-fingerprint", currentStableAccountID: nil)
        let repository = RepositorySpy()
        let codexAppProcessClient = RecordingCodexAppProcessClient()
        let workflow = SwitchAccountWorkflow(
            authService: auth,
            repository: repository,
            codexAppProcessClient: codexAppProcessClient,
            identityResolver: makeResolver(auth: auth)
        )

        let activeID = try await workflow.run(account: target, accounts: [target, other])

        #expect(auth.activatedAccountID == target.id)
        #expect(repository.savedAccounts?.map(\.id) == [target.id, other.id])
        #expect(codexAppProcessClient.relaunchCount == 1)
        #expect(activeID == target.id)
    }

    @Test
    func runDoesNotActivateOrPersistWhenCodexIsUnavailable() async throws {
        let target = makeAccount(name: "Target", fingerprint: "live-fingerprint")

        let auth = AuthSpy(currentFingerprint: "live-fingerprint", currentStableAccountID: nil)
        let repository = RepositorySpy()
        let codexAppProcessClient = RecordingCodexAppProcessClient()
        codexAppProcessClient.availabilityError = CodexAppProcessClientError.applicationNotFound
        let workflow = SwitchAccountWorkflow(
            authService: auth,
            repository: repository,
            codexAppProcessClient: codexAppProcessClient,
            identityResolver: makeResolver(auth: auth)
        )

        await #expect(throws: CodexAppProcessClientError.applicationNotFound) {
            try await workflow.run(account: target, accounts: [target])
        }

        #expect(auth.activatedAccountID == nil)
        #expect(repository.savedAccounts == nil)
        #expect(codexAppProcessClient.relaunchCount == 0)
    }

    @Test
    func runStillRelaunchesEvenWhenMatcherCannotResolveActiveAccount() async throws {
        let target = makeAccount(name: "Target", fingerprint: "saved-fingerprint")

        let auth = AuthSpy(currentFingerprint: "different-fingerprint", currentStableAccountID: nil)
        let repository = RepositorySpy()
        let codexAppProcessClient = RecordingCodexAppProcessClient()
        let workflow = SwitchAccountWorkflow(
            authService: auth,
            repository: repository,
            codexAppProcessClient: codexAppProcessClient,
            identityResolver: makeResolver(auth: auth)
        )

        let activeID = try await workflow.run(account: target, accounts: [target])

        #expect(activeID == nil)
        #expect(codexAppProcessClient.relaunchCount == 1)
    }

    private func makeAccount(name: String, fingerprint: String) -> CodexAccount {
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
                stableAccountID: nil,
                snapshotFingerprint: fingerprint,
                remoteIdentity: CodexRemoteAccountIdentity(emailAddress: "\(name.lowercased())@example.com")
            )
        )
    }
}

private final class AuthSpy: CodexAuthActivating, LiveCodexAccountIdentityReading {
    var activatedAccountID: UUID?
    private let fingerprint: String?
    private let stableAccountID: String?
    private let authPrincipalIdentity: CodexAuthPrincipalIdentity?
    private let workspaceIdentity: CodexWorkspaceIdentity?

    init(
        currentFingerprint: String?,
        currentStableAccountID: String?,
        currentAuthPrincipalIdentity: CodexAuthPrincipalIdentity? = nil,
        currentWorkspaceIdentity: CodexWorkspaceIdentity? = nil
    ) {
        self.fingerprint = currentFingerprint
        self.stableAccountID = currentStableAccountID
        self.authPrincipalIdentity = currentAuthPrincipalIdentity
        self.workspaceIdentity = currentWorkspaceIdentity
    }

    func activate(_ account: CodexAccount) throws {
        activatedAccountID = account.id
    }

    func readCurrentLiveAccountIdentity() -> LiveCodexAccountIdentity {
        LiveCodexAccountIdentity(
            stableAccountID: stableAccountID,
            authPrincipalIdentity: authPrincipalIdentity,
            workspaceIdentity: workspaceIdentity,
            snapshotFingerprint: fingerprint
        )
    }
}

private final class RepositorySpy: AccountCatalogStore {
    var savedAccounts: [CodexAccount]?

    func saveAccounts(_ accounts: [CodexAccount]) throws {
        savedAccounts = accounts
    }
}

private final class RecordingCodexAppProcessClient: CodexAppProcessClient {
    var relaunchCount = 0
    var availabilityCheckCount = 0
    var availabilityError: Error?

    func assertCodexAvailable() throws {
        availabilityCheckCount += 1
        if let availabilityError {
            throw availabilityError
        }
    }

    func relaunchCodex() async throws {
        relaunchCount += 1
    }
}

private func makeResolver(auth: AuthSpy) -> SavedAccountIdentityResolver {
    SavedAccountIdentityResolver(
        liveIdentityReader: auth,
        storedAccountReconciler: ReconcilePassthrough()
    )
}

private struct ReconcilePassthrough: StoredAccountIdentityReconciling {
    func reconcileStoredAccountIdentities(_ accounts: [CodexAccount]) -> [CodexAccount] {
        accounts
    }
}
