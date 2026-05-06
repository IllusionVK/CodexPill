import Foundation

struct CodexAppServerProcessRunner {
    private let sessionRunner = CodexAppServerSessionRunner()

    func readAccountStatus(
        configuration: CodexAppServerConfiguration,
        refreshToken: Bool,
        requireRateLimitResponse: Bool
    ) async throws -> CodexAppServerStatus {
        try await sessionRunner.readAccountStatus(command: CodexAppServerSessionCommand(
            executableURL: configuration.command.executableURL,
            arguments: configuration.command.arguments,
            environment: configuration.environment,
            timeout: configuration.responseTimeout,
            refreshToken: refreshToken,
            clientInfo: configuration.clientInfo,
            requireRateLimitResponse: requireRateLimitResponse,
            failure: { stderr, terminationStatus, timedOut in
                appServerFailure(stderr: stderr, terminationStatus: terminationStatus, timedOut: timedOut)
            }
        ))
    }
}
