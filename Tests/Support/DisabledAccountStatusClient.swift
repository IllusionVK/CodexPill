import Foundation

@testable import CodexPill

struct DisabledAccountStatusClient: CodexAccountStatusClient {
    func readCurrentAccountStatus() async throws -> CodexAccountStatus {
        throw DisabledAccountStatusClientError.unexpectedRead
    }
}

enum DisabledAccountStatusClientError: Error {
    case unexpectedRead
}
