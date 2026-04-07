import Foundation
import OSLog

private let authSnapshotLogger = Logger(subsystem: "com.raphhgg.codex-switchboard", category: "AuthSnapshot")

struct CodexAuthSnapshotService {
    private let repository: AccountRepository

    init(repository: AccountRepository) {
        self.repository = repository
    }

    func readCurrentAuthData() throws -> Data {
        authSnapshotLogger.log("Reading current auth data from \(repository.paths.codexAuthFile.path, privacy: .public)")
        return try Data(contentsOf: repository.paths.codexAuthFile)
    }

    func saveCurrentAuthSnapshot(
        named name: String,
        existing: CodexAccount? = nil
    ) throws -> CodexAccount {
        let authData = try readCurrentAuthData()
        var account = existing ?? CodexAccount(
            id: UUID(),
            name: name,
            snapshotFileName: "\(UUID().uuidString).json",
            createdAt: Date(),
            updatedAt: Date(),
            email: nil,
            planType: nil,
            rateLimits: nil
        )
        account.name = name
        account.updatedAt = Date()
        try repository.writeSnapshot(data: authData, for: account)
        return account
    }

    func activate(_ account: CodexAccount) throws {
        authSnapshotLogger.log("Activating snapshot for account name: \(account.name, privacy: .public)")
        let snapshot = try repository.readSnapshot(for: account)
        try snapshot.write(to: repository.paths.codexAuthFile, options: .atomic)
    }

    func prepareForNewSignIn() throws {
        let authFile = repository.paths.codexAuthFile
        let fileManager = FileManager.default

        let exists = fileManager.fileExists(atPath: authFile.path)
        authSnapshotLogger.log("Preparing for new sign-in. Auth file exists: \(exists, privacy: .public)")
        guard exists else { return }
        authSnapshotLogger.log("Removing auth file at \(authFile.path, privacy: .public)")
        try fileManager.removeItem(at: authFile)
        authSnapshotLogger.log("Removed auth file successfully")
    }

    func isActive(_ account: CodexAccount) -> Bool {
        guard
            let current = try? Data(contentsOf: repository.paths.codexAuthFile),
            let snapshot = try? repository.readSnapshot(for: account)
        else {
            return false
        }

        return current == snapshot
    }
}
