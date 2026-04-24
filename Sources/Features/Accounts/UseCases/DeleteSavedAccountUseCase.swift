import Foundation

protocol AccountSnapshotRemover: AccountCatalogStore {
    func deleteSnapshot(for account: CodexAccount) throws
}

extension AccountRepository: AccountSnapshotRemover {}

struct DeleteSavedAccountResult {
    let accounts: [CodexAccount]
    let activeAccountID: UUID?
}

struct DeleteSavedAccountUseCase {
    private let repository: AccountSnapshotRemover
    private let identityResolver: SavedAccountIdentityResolver

    init(
        repository: AccountSnapshotRemover,
        identityResolver: SavedAccountIdentityResolver
    ) {
        self.repository = repository
        self.identityResolver = identityResolver
    }

    func run(account: CodexAccount, accounts: [CodexAccount]) throws -> DeleteSavedAccountResult {
        try repository.deleteSnapshot(for: account)
        let updatedAccounts = accounts.filter { $0.id != account.id }
        try repository.saveAccounts(updatedAccounts)

        return DeleteSavedAccountResult(
            accounts: updatedAccounts,
            activeAccountID: identityResolver.resolveCurrentAccountID(accounts: updatedAccounts)
        )
    }
}
