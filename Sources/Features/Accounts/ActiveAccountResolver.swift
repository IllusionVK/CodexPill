import Foundation

protocol CodexAuthFingerprintReading {
    func currentAuthFingerprint() -> String?
    func currentStableAccountID() -> String?
    func currentAuthPrincipalIdentity() -> CodexAuthPrincipalIdentity?
    func currentWorkspaceIdentity() -> CodexWorkspaceIdentity?
}

extension CodexAuthSnapshotService: CodexAuthFingerprintReading {}

struct ActiveAccountResolver {
    private let authService: CodexAuthFingerprintReading
    private let accountMatcher: CodexAccountMatcher

    init(
        authService: CodexAuthFingerprintReading,
        accountMatcher: CodexAccountMatcher = CodexAccountMatcher()
    ) {
        self.authService = authService
        self.accountMatcher = accountMatcher
    }

    func resolve(
        accounts: [CodexAccount],
        liveRemoteIdentity: CodexRemoteAccountIdentity? = nil
    ) -> CodexAccountMatchOutcome {
        accountMatcher.match(
            liveStableAccountID: authService.currentStableAccountID(),
            liveAuthPrincipalIdentity: authService.currentAuthPrincipalIdentity(),
            liveWorkspaceIdentity: authService.currentWorkspaceIdentity(),
            liveAuthFingerprint: authService.currentAuthFingerprint(),
            liveRemoteIdentity: liveRemoteIdentity,
            accounts: accounts
        )
    }

    func resolveActiveAccountID(
        accounts: [CodexAccount],
        liveRemoteIdentity: CodexRemoteAccountIdentity? = nil
    ) -> UUID? {
        resolve(
            accounts: accounts,
            liveRemoteIdentity: liveRemoteIdentity
        ).matchedAccountID
    }
}
