import Foundation

struct RemoteHostConfig: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var sshTarget: String

    init(id: UUID, name: String, sshTarget: String) {
        self.id = id
        self.name = name
        self.sshTarget = sshTarget
    }

    init(id: UUID, name: String, sshAlias: String) {
        self.init(id: id, name: name, sshTarget: sshAlias)
    }

    var sshAlias: String {
        sshTarget
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case sshTarget
        case sshAlias
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        sshTarget =
            try container.decodeIfPresent(String.self, forKey: .sshTarget)
            ?? container.decode(String.self, forKey: .sshAlias)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(sshTarget, forKey: .sshTarget)
    }
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
