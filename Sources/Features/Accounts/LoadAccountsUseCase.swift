import Foundation

protocol AccountCatalogLoading: AccountCatalogPersisting {
    func bootstrapStorage() throws
    func loadAccounts() throws -> [CodexAccount]
}

extension AccountRepository: AccountCatalogLoading {}

protocol StoredAccountReconciling {
    func reconcileStoredAccountIdentities(_ accounts: [CodexAccount]) -> [CodexAccount]
}

extension CodexAuthSnapshotService: StoredAccountReconciling {}

struct LoadAccountsResult {
    let accounts: [CodexAccount]
    let activeAccountID: UUID?
}

struct LoadAccountsUseCase {
    private let repository: AccountCatalogLoading
    private let authService: StoredAccountReconciling
    private let activeAccountResolver: ActiveAccountResolver

    init(
        repository: AccountCatalogLoading,
        authService: StoredAccountReconciling,
        activeAccountResolver: ActiveAccountResolver
    ) {
        self.repository = repository
        self.authService = authService
        self.activeAccountResolver = activeAccountResolver
    }

    func run() throws -> LoadAccountsResult {
        try repository.bootstrapStorage()
        let loadedAccounts = try repository.loadAccounts()
        let reconciledAccounts = authService.reconcileStoredAccountIdentities(loadedAccounts)
        if reconciledAccounts != loadedAccounts {
            try repository.saveAccounts(reconciledAccounts)
        }

        return LoadAccountsResult(
            accounts: reconciledAccounts,
            activeAccountID: activeAccountResolver.resolveActiveAccountID(accounts: reconciledAccounts)
        )
    }
}
