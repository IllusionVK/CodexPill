import CryptoKit
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
            rateLimits: nil,
            identity: .empty
        )
        account.name = name
        account.updatedAt = Date()
        account.identity.stableAccountID = Self.stableAccountID(for: authData)
        account.identity.authPrincipalIdentity = Self.authPrincipalIdentity(for: authData)
        account.identity.workspaceIdentity = Self.workspaceIdentity(for: authData)
        account.identity.snapshotFingerprint = Self.snapshotFingerprint(for: authData)
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

    func currentAuthFingerprint() -> String? {
        guard let current = try? Data(contentsOf: repository.paths.codexAuthFile) else {
            return nil
        }
        return Self.snapshotFingerprint(for: current)
    }

    func currentStableAccountID() -> String? {
        guard let current = try? Data(contentsOf: repository.paths.codexAuthFile) else {
            return nil
        }
        return Self.stableAccountID(for: current)
    }

    func currentAuthPrincipalIdentity() -> CodexAuthPrincipalIdentity? {
        guard let current = try? Data(contentsOf: repository.paths.codexAuthFile) else {
            return nil
        }
        return Self.authPrincipalIdentity(for: current)
    }

    func currentWorkspaceIdentity() -> CodexWorkspaceIdentity? {
        guard let current = try? Data(contentsOf: repository.paths.codexAuthFile) else {
            return nil
        }
        return Self.workspaceIdentity(for: current)
    }

    func reconcileStoredAccountIdentities(_ accounts: [CodexAccount]) -> [CodexAccount] {
        accounts.map { account in
            var reconciled = account

            if (
                reconciled.identity.stableAccountID == nil ||
                    reconciled.identity.authPrincipalIdentity == nil ||
                    reconciled.identity.workspaceIdentity == nil ||
                    reconciled.identity.snapshotFingerprint == nil
            ),
               let snapshot = try? repository.readSnapshot(for: account) {
                if reconciled.identity.stableAccountID == nil {
                    reconciled.identity.stableAccountID = Self.stableAccountID(for: snapshot)
                }
                if reconciled.identity.authPrincipalIdentity == nil {
                    reconciled.identity.authPrincipalIdentity = Self.authPrincipalIdentity(for: snapshot)
                }
                if reconciled.identity.workspaceIdentity == nil {
                    reconciled.identity.workspaceIdentity = Self.workspaceIdentity(for: snapshot)
                }
                if reconciled.identity.snapshotFingerprint == nil {
                    reconciled.identity.snapshotFingerprint = Self.snapshotFingerprint(for: snapshot)
                }
            }

            if reconciled.identity.remoteIdentity == nil {
                reconciled.identity.remoteIdentity = CodexRemoteAccountIdentity(emailAddress: reconciled.email)
            }

            return reconciled
        }
    }

    private static func snapshotFingerprint(for data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func stableAccountID(for data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let tokens = object["tokens"] as? [String: Any]
        else {
            return nil
        }

        let accountID = tokens["account_id"] as? String
        let trimmed = accountID?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    static func authPrincipalIdentity(for data: Data) -> CodexAuthPrincipalIdentity? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let tokens = object["tokens"] as? [String: Any],
            let idToken = tokens["id_token"] as? String,
            let payload = decodeJWTPayload(idToken)
        else {
            return nil
        }

        let auth = payload["https://api.openai.com/auth"] as? [String: Any]
        let identity = CodexAuthPrincipalIdentity(
            subject: payload["sub"] as? String,
            chatGPTUserID: auth?["chatgpt_user_id"] as? String
        )

        return identity.isMeaningful ? identity : nil
    }

    static func workspaceIdentity(for data: Data) -> CodexWorkspaceIdentity? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let tokens = object["tokens"] as? [String: Any],
            let idToken = tokens["id_token"] as? String,
            let payload = decodeJWTPayload(idToken),
            let auth = payload["https://api.openai.com/auth"] as? [String: Any]
        else {
            return nil
        }

        let organizations = auth["organizations"] as? [[String: Any]] ?? []
        let defaultOrganization = organizations.first(where: { organization in
            organization["is_default"] as? Bool == true
        }) ?? organizations.first

        let workspace = CodexWorkspaceIdentity(
            workspaceAccountID: defaultOrganization?["id"] as? String,
            workspaceLabel: defaultOrganization?["title"] as? String
        )

        return workspace.isMeaningful ? workspace : nil
    }

    private static func decodeJWTPayload(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }

        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 {
            payload.append("=")
        }

        guard let data = Data(base64Encoded: payload) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
