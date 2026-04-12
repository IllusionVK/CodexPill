import Foundation

struct RemoteHostConfig: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var sshAlias: String
}

struct ObservedExecutionContext: Identifiable, Equatable {
    enum Kind: Equatable {
        case local
        case sshHost(hostID: UUID)
    }

    enum Status: Equatable {
        case matched(accountID: UUID)
        case unmatched(RemoteObservedIdentitySummary)
        case unavailable(message: String)
        case loading
    }

    let id: String
    let kind: Kind
    let displayName: String
    let status: Status
    let lastObservedAt: Date?
}

struct RemoteObservedIdentitySummary: Equatable {
    let email: String?
    let planType: String?
}

struct RemoteHostObservation: Equatable {
    let host: RemoteHostConfig
    let liveIdentity: LiveCodexAccountIdentity
    let remoteIdentity: CodexRemoteAccountIdentity?
    let email: String?
    let planType: String?
}

enum RemoteHostObservationResult: Equatable {
    case success(RemoteHostObservation)
    case failure(String)
}
