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

    func run(alias: String, hosts: [RemoteHostConfig]) throws -> AddRemoteHostResult {
        let resolvedAlias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !resolvedAlias.isEmpty else {
            throw AddRemoteHostUseCaseError.emptyHostAlias
        }

        guard !hosts.contains(where: { $0.sshAlias.caseInsensitiveCompare(resolvedAlias) == .orderedSame }) else {
            throw AddRemoteHostUseCaseError.duplicateHostAlias
        }

        let host = RemoteHostConfig(
            id: UUID(),
            name: resolvedAlias,
            sshAlias: resolvedAlias
        )
        let updatedHosts = (hosts + [host]).sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        try repository.saveHosts(updatedHosts)

        return AddRemoteHostResult(hosts: updatedHosts, addedHost: host)
    }
}

enum AddRemoteHostUseCaseError: LocalizedError {
    case emptyHostAlias
    case duplicateHostAlias

    var errorDescription: String? {
        switch self {
        case .emptyHostAlias:
            "Host alias cannot be empty."
        case .duplicateHostAlias:
            "A host with that alias already exists."
        }
    }
}
