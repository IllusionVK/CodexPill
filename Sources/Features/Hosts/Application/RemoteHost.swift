import Foundation

struct RemoteHost: Codable, Equatable {
    let destination: String
    let displayName: String

    init(destination: String, displayName: String? = nil) {
        let trimmed = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDisplayName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.destination = trimmed
        self.displayName = (trimmedDisplayName?.isEmpty == false ? trimmedDisplayName : nil) ?? Self.defaultDisplayName(for: trimmed)
    }

    private static func defaultDisplayName(for destination: String) -> String {
        guard let hostComponent = destination.split(separator: "@").last else {
            return destination
        }
        return String(hostComponent)
    }
}

enum RemoteHostAccountInstallationState: String, Codable, Equatable {
    case installed
    case missing
}

protocol RemoteHostConnectionChecking {
    func testConnection(to host: RemoteHost) async throws
}

protocol RemoteHostAccountInstalling {
    func installationState(for account: CodexAccount, on host: RemoteHost) async throws -> RemoteHostAccountInstallationState
    func installAccount(_ account: CodexAccount, on host: RemoteHost) async throws
}

protocol RemoteHostAccountSwitching {
    func switchToAccount(_ account: CodexAccount, on host: RemoteHost) async throws
}

protocol RemoteHostAccountSigningOut {
    func signOut(on host: RemoteHost) async throws
}

protocol RemoteHostCodexAppServerRefreshing {
    func refreshCodexAppServer(on host: RemoteHost) async throws
}

protocol RemoteHostAccountStatusReading {
    func readCurrentAccountStatus(on host: RemoteHost) async throws -> CodexAccountStatus
}

typealias RemoteHostSwitchWorkflowOperations =
    RemoteHostConnectionChecking
    & RemoteHostAccountInstalling
    & RemoteHostAccountSwitching
    & RemoteHostCodexAppServerRefreshing
    & RemoteHostAccountStatusReading

enum RemoteHostClientError: LocalizedError, Equatable {
    case unavailable
    case commandFailed(String)
    case nonInteractiveSSHSetupRequired
    case authReadFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Remote host switching is not configured yet."
        case .commandFailed(let message):
            return message
        case .nonInteractiveSSHSetupRequired:
            return "SSH is not ready for non-interactive use. Configure keys, host trust, passphrases, 2FA, or SSH config outside CodexPill, then try again."
        case .authReadFailed(let message):
            return message
        }
    }
}

struct UnavailableRemoteHostClient:
    RemoteHostConnectionChecking,
    RemoteHostAccountInstalling,
    RemoteHostAccountSwitching,
    RemoteHostAccountSigningOut,
    RemoteHostCodexAppServerRefreshing,
    RemoteHostAccountStatusReading
{
    func testConnection(to host: RemoteHost) async throws {
        throw RemoteHostClientError.unavailable
    }

    func installationState(for account: CodexAccount, on host: RemoteHost) async throws -> RemoteHostAccountInstallationState {
        throw RemoteHostClientError.unavailable
    }

    func installAccount(_ account: CodexAccount, on host: RemoteHost) async throws {
        throw RemoteHostClientError.unavailable
    }

    func switchToAccount(_ account: CodexAccount, on host: RemoteHost) async throws {
        throw RemoteHostClientError.unavailable
    }

    func signOut(on host: RemoteHost) async throws {
        throw RemoteHostClientError.unavailable
    }

    func refreshCodexAppServer(on host: RemoteHost) async throws {
        throw RemoteHostClientError.unavailable
    }

    func readCurrentAccountStatus(on host: RemoteHost) async throws -> CodexAccountStatus {
        throw RemoteHostClientError.unavailable
    }
}
