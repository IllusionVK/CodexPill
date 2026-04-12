import Foundation

struct DeleteRemoteHostResult {
    let hosts: [RemoteHostConfig]
}

struct DeleteRemoteHostUseCase {
    private let repository: RemoteHostCatalogPersisting

    init(repository: RemoteHostCatalogPersisting) {
        self.repository = repository
    }

    func run(host: RemoteHostConfig, hosts: [RemoteHostConfig]) throws -> DeleteRemoteHostResult {
        let updatedHosts = hosts.filter { $0.id != host.id }
        try repository.saveHosts(updatedHosts)
        return DeleteRemoteHostResult(hosts: updatedHosts)
    }
}
