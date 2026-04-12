import Foundation

struct RemoteHostCodexObserver: RemoteHostObserving {
    private let transport: RemoteHostAuthDataTransporting

    init(transport: RemoteHostAuthDataTransporting = SSHRemoteHostAuthDataTransport()) {
        self.transport = transport
    }

    func observe(host: RemoteHostConfig) async -> RemoteHostObservationResult {
        switch await transport.readAuthData(host: host) {
        case .failure(let error):
            return .failure(error.localizedDescription)
        case .success(let data):
            let observation = RemoteHostObservation(
                host: host,
                liveIdentity: LiveCodexAccountIdentity(
                    stableAccountID: CodexAuthDataParser.stableAccountID(from: data),
                    authPrincipalIdentity: CodexAuthDataParser.authPrincipalIdentity(from: data),
                    workspaceIdentity: CodexAuthDataParser.workspaceIdentity(from: data),
                    snapshotFingerprint: nil
                ),
                remoteIdentity: CodexAuthDataParser.remoteIdentity(from: data),
                email: CodexAuthDataParser.email(from: data),
                planType: CodexAuthDataParser.planType(from: data)
            )
            return .success(observation)
        }
    }
}
