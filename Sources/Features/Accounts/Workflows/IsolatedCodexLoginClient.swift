import Foundation

struct IsolatedCodexLoginPrompt: Equatable {
    let url: URL
    let userCode: String
}

protocol IsolatedCodexLoginSession: AnyObject {
    var prompt: IsolatedCodexLoginPrompt { get }
    var codexHome: URL { get }
    func waitForAuthData() async throws -> Data
    func verifyLoginStatus() async -> Bool
    func cancel()
    func cleanup()
}

protocol IsolatedCodexLoginClient {
    func startLogin() async throws -> IsolatedCodexLoginSession
}

enum IsolatedCodexLoginError: LocalizedError {
    case promptUnavailable
    case authCaptureFailed
    case authCaptureTimedOut
    case loginStatusVerificationFailed

    var errorDescription: String? {
        switch self {
        case .promptUnavailable:
            "Codex could not start a sign-in session. Try again in a few minutes."
        case .authCaptureFailed:
            "The Codex sign-in did not complete."
        case .authCaptureTimedOut:
            "The Codex sign-in code expired before the account was added."
        case .loginStatusVerificationFailed:
            "CodexPill could not verify the signed-in account."
        }
    }
}
