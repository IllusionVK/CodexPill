import Foundation
import Testing

@testable import CodexPill

struct RemoteHostCodexObserverTests {
    @Test
    func observeBuildsObservationFromRemoteAuthData() async throws {
        let host = RemoteHostConfig(id: UUID(), name: "debian-vm", sshAlias: "debian-vm")
        let transport = RemoteHostTransportStub(result: .success(try makeAuthData()))
        let observer = RemoteHostCodexObserver(transport: transport)

        let result = await observer.observe(host: host)

        guard case let .success(observation) = result else {
            Issue.record("Expected successful observation")
            return
        }

        #expect(observation.host == host)
        #expect(observation.liveIdentity.stableAccountID == "acct-123")
        #expect(observation.liveIdentity.authPrincipalIdentity == CodexAuthPrincipalIdentity(
            subject: "auth0|principal-123",
            chatGPTUserID: "user-123"
        ))
        #expect(observation.liveIdentity.workspaceIdentity == CodexWorkspaceIdentity(
            workspaceAccountID: "org-team",
            workspaceLabel: "Team"
        ))
        #expect(observation.remoteIdentity == CodexRemoteAccountIdentity(emailAddress: "person@example.com"))
        #expect(observation.email == "person@example.com")
        #expect(observation.planType == "team")
    }

    @Test
    func observePassesTransportFailureThrough() async {
        let host = RemoteHostConfig(id: UUID(), name: "debian-vm", sshAlias: "debian-vm")
        let observer = RemoteHostCodexObserver(
            transport: RemoteHostTransportStub(result: .failure(.commandFailed("Host unreachable")))
        )

        let result = await observer.observe(host: host)

        #expect(result == .failure("Host unreachable"))
    }

    private func makeAuthData() throws -> Data {
        let payload: [String: Any] = [
            "sub": "auth0|principal-123",
            "email": "person@example.com",
            "https://api.openai.com/auth": [
                "chatgpt_user_id": "user-123",
                "chatgpt_plan_type": "team",
            ],
            "https://api.openai.com/organizations": [
                [
                    "id": "org-secondary",
                    "title": "Secondary",
                    "is_default": false,
                ],
                [
                    "id": "org-team",
                    "title": "Team",
                    "is_default": true,
                ],
            ],
        ]

        let header = try makeJWTPart(["alg": "none", "typ": "JWT"])
        let jwtPayload = try makeJWTPart(payload)
        let token = "\(header).\(jwtPayload).signature"
        let auth: [String: Any] = [
            "tokens": [
                "account_id": "acct-123",
                "id_token": token,
            ],
        ]
        return try JSONSerialization.data(withJSONObject: auth)
    }

    private func makeJWTPart(_ object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object)
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private struct RemoteHostTransportStub: RemoteHostAuthDataTransporting {
    let result: Result<Data, RemoteHostTransportError>

    func readAuthData(host: RemoteHostConfig) async -> Result<Data, RemoteHostTransportError> {
        result
    }
}
