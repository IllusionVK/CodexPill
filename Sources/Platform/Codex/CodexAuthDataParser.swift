import Foundation

enum CodexAuthDataParser {
    static func stableAccountID(from data: Data) -> String? {
        guard
            let object = jsonObject(from: data),
            let tokens = object["tokens"] as? [String: Any]
        else {
            return nil
        }

        let accountID = tokens["account_id"] as? String
        let trimmed = accountID?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    static func authPrincipalIdentity(from data: Data) -> CodexAuthPrincipalIdentity? {
        guard let payload = jwtPayload(from: data) else { return nil }

        let auth = payload["https://api.openai.com/auth"] as? [String: Any]
        let identity = CodexAuthPrincipalIdentity(
            subject: payload["sub"] as? String,
            chatGPTUserID: auth?["chatgpt_user_id"] as? String
        )

        return identity.isMeaningful ? identity : nil
    }

    static func workspaceIdentity(from data: Data) -> CodexWorkspaceIdentity? {
        guard let payload = jwtPayload(from: data) else { return nil }

        let organizations = organizations(from: payload)
        let defaultOrganization = organizations.first(where: {
            $0["is_default"] as? Bool == true
        }) ?? organizations.first

        let workspace = CodexWorkspaceIdentity(
            workspaceAccountID: defaultOrganization?["id"] as? String,
            workspaceLabel: defaultOrganization?["title"] as? String
        )

        return workspace.isMeaningful ? workspace : nil
    }

    static func email(from data: Data) -> String? {
        jwtPayload(from: data)?["email"] as? String
    }

    static func planType(from data: Data) -> String? {
        let auth = jwtPayload(from: data)?["https://api.openai.com/auth"] as? [String: Any]
        return auth?["chatgpt_plan_type"] as? String
    }

    static func remoteIdentity(from data: Data) -> CodexRemoteAccountIdentity? {
        CodexRemoteAccountIdentity(emailAddress: email(from: data))
    }

    private static func jsonObject(from data: Data) -> [String: Any]? {
        try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func jwtPayload(from data: Data) -> [String: Any]? {
        guard
            let object = jsonObject(from: data),
            let idToken = idToken(in: object)
        else {
            return nil
        }

        return decodeJWTPayload(idToken)
    }

    private static func idToken(in object: [String: Any]) -> String? {
        if let idToken = object["id_token"] as? String, !idToken.isEmpty {
            return idToken
        }

        if
            let tokens = object["tokens"] as? [String: Any],
            let idToken = tokens["id_token"] as? String,
            !idToken.isEmpty
        {
            return idToken
        }

        return nil
    }

    private static func organizations(from payload: [String: Any]) -> [[String: Any]] {
        if let organizations = payload["https://api.openai.com/organizations"] as? [[String: Any]], !organizations.isEmpty {
            return organizations
        }

        let auth = payload["https://api.openai.com/auth"] as? [String: Any]
        return auth?["organizations"] as? [[String: Any]] ?? []
    }

    private static func decodeJWTPayload(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }

        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 {
            payload.append("=")
        }

        guard let data = Data(base64Encoded: payload) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
