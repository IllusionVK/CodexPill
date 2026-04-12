import Foundation

struct RemoteHostCodexObserver: RemoteHostObserving {
    func observe(host: RemoteHostConfig) async -> RemoteHostObservationResult {
        await withCheckedContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            let inputPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
            process.arguments = [
                "-o", "RemoteCommand=none",
                "-o", "ConnectTimeout=5",
                "-T",
                host.sshAlias,
                "python3",
                "-"
            ]
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            process.standardInput = inputPipe
            process.terminationHandler = { process in
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorText = String(data: errorData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                guard process.terminationStatus == 0 else {
                    continuation.resume(returning: .failure(errorText ?? "SSH observation failed"))
                    return
                }

                do {
                    let payload = try JSONDecoder().decode(RemoteHostObservationPayload.self, from: outputData)
                    let observation = RemoteHostObservation(
                        host: host,
                        liveIdentity: LiveCodexAccountIdentity(
                            stableAccountID: payload.accountID,
                            authPrincipalIdentity: CodexAuthPrincipalIdentity(
                                subject: payload.subject,
                                chatGPTUserID: payload.chatGPTUserID
                            ),
                            workspaceIdentity: payload.defaultOrganization.map {
                                CodexWorkspaceIdentity(
                                    workspaceAccountID: $0.id,
                                    workspaceLabel: $0.title
                                )
                            },
                            snapshotFingerprint: nil
                        ),
                        remoteIdentity: CodexRemoteAccountIdentity(emailAddress: payload.email),
                        email: payload.email,
                        planType: payload.planType
                    )
                    continuation.resume(returning: .success(observation))
                } catch {
                    continuation.resume(returning: .failure("Failed to decode remote host identity"))
                }
            }

            do {
                try process.run()
                let scriptData = Data(remoteObservationScript().utf8)
                inputPipe.fileHandleForWriting.write(scriptData)
                try inputPipe.fileHandleForWriting.close()
            } catch {
                continuation.resume(returning: .failure(error.localizedDescription))
            }
        }
    }

    private func remoteObservationScript() -> String {
        #"""
import json, base64, pathlib
path = pathlib.Path.home() / ".codex" / "auth.json"
raw = json.loads(path.read_text())
token = raw.get("id_token") or raw.get("tokens", {}).get("id_token")
claims = {}
if token and token.count(".") >= 2:
    payload = token.split(".")[1]
    payload += "=" * (-len(payload) % 4)
    claims = json.loads(base64.urlsafe_b64decode(payload.encode()).decode())
organizations = claims.get("https://api.openai.com/organizations", []) or []
default_org = None
for org in organizations:
    if org.get("is_default"):
        default_org = {
            "id": org.get("id"),
            "title": org.get("title"),
        }
        break
summary = {
    "accountID": raw.get("tokens", {}).get("account_id"),
    "subject": claims.get("sub"),
    "chatGPTUserID": claims.get("https://api.openai.com/auth", {}).get("chatgpt_user_id"),
    "email": claims.get("email"),
    "planType": claims.get("https://api.openai.com/auth", {}).get("chatgpt_plan_type"),
    "defaultOrganization": default_org,
}
print(json.dumps(summary))
"""#
    }
}

private struct RemoteHostObservationPayload: Decodable {
    struct DefaultOrganization: Decodable {
        let id: String?
        let title: String?
    }

    let accountID: String?
    let subject: String?
    let chatGPTUserID: String?
    let email: String?
    let planType: String?
    let defaultOrganization: DefaultOrganization?
}
