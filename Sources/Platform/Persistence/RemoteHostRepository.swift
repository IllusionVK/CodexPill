import Foundation

protocol RemoteHostCatalogLoading {
    func loadHosts() throws -> [RemoteHostConfig]
}

protocol RemoteHostCatalogPersisting {
    func saveHosts(_ hosts: [RemoteHostConfig]) throws
}

typealias RemoteHostCatalog = RemoteHostCatalogLoading & RemoteHostCatalogPersisting

struct RemoteHostRepository: RemoteHostCatalog {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    let paths: AppPaths

    init(fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        self.paths = try AppPaths(fileManager: fileManager)
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
    }

    func loadHosts() throws -> [RemoteHostConfig] {
        guard fileManager.fileExists(atPath: paths.remoteHostsFile.path) else { return [] }
        let data = try Data(contentsOf: paths.remoteHostsFile)
        return try decoder.decode([RemoteHostConfig].self, from: data)
    }

    func saveHosts(_ hosts: [RemoteHostConfig]) throws {
        try fileManager.createDirectory(at: paths.appSupportDirectory, withIntermediateDirectories: true)
        let data = try encoder.encode(hosts)
        try data.write(to: paths.remoteHostsFile, options: .atomic)
    }
}
