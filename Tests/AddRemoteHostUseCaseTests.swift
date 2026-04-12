import Foundation
import Testing

@testable import CodexPill

struct AddRemoteHostUseCaseTests {
    @Test
    func runPersistsTrimmedHostAlias() throws {
        let repository = RemoteHostRepositorySpy()
        let useCase = AddRemoteHostUseCase(repository: repository)

        let result = try useCase.run(
            alias: "  debian-vm  ",
            hosts: []
        )

        #expect(result.addedHost.sshAlias == "debian-vm")
        #expect(result.addedHost.name == "debian-vm")
        #expect(result.hosts.map(\.sshAlias) == ["debian-vm"])
        #expect(repository.savedHosts?.map(\.sshAlias) == ["debian-vm"])
    }

    @Test
    func runRejectsBlankAlias() {
        let useCase = AddRemoteHostUseCase(repository: RemoteHostRepositorySpy())

        #expect(throws: AddRemoteHostUseCaseError.emptyHostAlias) {
            try useCase.run(alias: "   ", hosts: [])
        }
    }

    @Test
    func runRejectsDuplicateAliasCaseInsensitively() {
        let existing = RemoteHostConfig(id: UUID(), name: "Debian", sshAlias: "debian-vm")
        let useCase = AddRemoteHostUseCase(repository: RemoteHostRepositorySpy())

        #expect(throws: AddRemoteHostUseCaseError.duplicateHostAlias) {
            try useCase.run(alias: "Debian-VM", hosts: [existing])
        }
    }
}

private final class RemoteHostRepositorySpy: RemoteHostCatalogPersisting {
    var savedHosts: [RemoteHostConfig]?

    func saveHosts(_ hosts: [RemoteHostConfig]) throws {
        savedHosts = hosts
    }
}
