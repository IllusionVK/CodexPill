import Foundation
import Testing

@testable import CodexPill

struct AddRemoteHostUseCaseTests {
    @Test
    func remoteHostConfigDecodesLegacySshAliasField() throws {
        let data = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "name": "Debian",
          "sshAlias": "debian-vm"
        }
        """.data(using: .utf8)!

        let host = try JSONDecoder().decode(RemoteHostConfig.self, from: data)

        #expect(host.name == "Debian")
        #expect(host.sshTarget == "debian-vm")
    }

    @Test
    func runPersistsTrimmedHostTargetAndDerivedName() throws {
        let repository = RemoteHostRepositorySpy()
        let useCase = AddRemoteHostUseCase(repository: repository)

        let result = try useCase.run(
            name: "  ",
            sshTarget: "  debian-vm  ",
            hosts: []
        )

        #expect(result.addedHost.sshTarget == "debian-vm")
        #expect(result.addedHost.name == "debian-vm")
        #expect(result.hosts.map(\.sshTarget) == ["debian-vm"])
        #expect(repository.savedHosts?.map(\.sshTarget) == ["debian-vm"])
    }

    @Test
    func runUsesExplicitDisplayNameWhenProvided() throws {
        let repository = RemoteHostRepositorySpy()
        let useCase = AddRemoteHostUseCase(repository: repository)

        let result = try useCase.run(
            name: "Debian VM",
            sshTarget: "raphael@192.168.1.20",
            hosts: []
        )

        #expect(result.addedHost.name == "Debian VM")
        #expect(result.addedHost.sshTarget == "raphael@192.168.1.20")
    }

    @Test
    func runRejectsBlankTarget() {
        let useCase = AddRemoteHostUseCase(repository: RemoteHostRepositorySpy())

        #expect(throws: AddRemoteHostUseCaseError.emptyHostTarget) {
            try useCase.run(name: "Debian", sshTarget: "   ", hosts: [])
        }
    }

    @Test
    func runRejectsDuplicateTargetCaseInsensitively() {
        let existing = RemoteHostConfig(id: UUID(), name: "Debian", sshAlias: "debian-vm")
        let useCase = AddRemoteHostUseCase(repository: RemoteHostRepositorySpy())

        #expect(throws: AddRemoteHostUseCaseError.duplicateHostTarget) {
            try useCase.run(name: "Other", sshTarget: "Debian-VM", hosts: [existing])
        }
    }
}

struct DeleteRemoteHostUseCaseTests {
    @Test
    func runRemovesMatchingHostAndPersistsCatalog() throws {
        let debian = RemoteHostConfig(id: UUID(), name: "debian-vm", sshAlias: "debian-vm")
        let macMini = RemoteHostConfig(id: UUID(), name: "mac-mini", sshAlias: "mac-mini")
        let repository = RemoteHostRepositorySpy()
        let useCase = DeleteRemoteHostUseCase(repository: repository)

        let result = try useCase.run(host: debian, hosts: [debian, macMini])

        #expect(result.hosts == [macMini])
        #expect(repository.savedHosts == [macMini])
    }
}

private final class RemoteHostRepositorySpy: RemoteHostCatalogPersisting {
    var savedHosts: [RemoteHostConfig]?

    func saveHosts(_ hosts: [RemoteHostConfig]) throws {
        savedHosts = hosts
    }
}
