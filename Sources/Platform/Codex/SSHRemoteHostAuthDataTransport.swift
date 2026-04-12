import Foundation

protocol RemoteHostAuthDataTransporting {
    func readAuthData(host: RemoteHostConfig) async -> Result<Data, RemoteHostTransportError>
}

struct SSHRemoteHostAuthDataTransport: RemoteHostAuthDataTransporting {
    func readAuthData(host: RemoteHostConfig) async -> Result<Data, RemoteHostTransportError> {
        await withCheckedContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
            process.arguments = [
                "-o", "RemoteCommand=none",
                "-o", "ConnectTimeout=5",
                "-T",
                host.sshTarget,
                "cat ~/.codex/auth.json"
            ]
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            process.terminationHandler = { process in
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorText = String(data: errorData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                guard process.terminationStatus == 0 else {
                    continuation.resume(returning: .failure(
                        .commandFailed(errorText ?? "SSH observation failed")
                    ))
                    return
                }

                continuation.resume(returning: .success(outputData))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(returning: .failure(.launchFailed(error.localizedDescription)))
            }
        }
    }
}

enum RemoteHostTransportError: LocalizedError, Equatable {
    case launchFailed(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .launchFailed(let message), .commandFailed(let message):
            message
        }
    }
}
