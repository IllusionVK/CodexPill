import Foundation

struct AddRemoteHostResult {
    let hosts: [RemoteHostConfig]
    let addedHost: RemoteHostConfig
}

struct AddRemoteHostUseCase {
    private let repository: RemoteHostCatalogPersisting

    init(repository: RemoteHostCatalogPersisting) {
        self.repository = repository
    }

    func makeHost(name: String, sshTarget: String, hosts: [RemoteHostConfig]) throws -> RemoteHostConfig {
        let resolvedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTarget = sshTarget.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !resolvedTarget.isEmpty else {
            throw AddRemoteHostUseCaseError.emptyHostTarget
        }

        guard !hosts.contains(where: { $0.sshTarget.caseInsensitiveCompare(resolvedTarget) == .orderedSame }) else {
            throw AddRemoteHostUseCaseError.duplicateHostTarget
        }

        let displayName = resolvedName.isEmpty ? resolvedTarget : resolvedName
        return RemoteHostConfig(
            id: UUID(),
            name: displayName,
            sshTarget: resolvedTarget
        )
    }

    func run(name: String, sshTarget: String, hosts: [RemoteHostConfig]) throws -> AddRemoteHostResult {
        let host = try makeHost(name: name, sshTarget: sshTarget, hosts: hosts)
        let updatedHosts = (hosts + [host]).sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        try repository.saveHosts(updatedHosts)

        return AddRemoteHostResult(hosts: updatedHosts, addedHost: host)
    }
}

enum AddRemoteHostUseCaseError: LocalizedError {
    case emptyHostTarget
    case duplicateHostTarget

    var errorDescription: String? {
        switch self {
        case .emptyHostTarget:
            "SSH target cannot be empty."
        case .duplicateHostTarget:
            "A host with that SSH target already exists."
        }
    }
}
