import Foundation

struct CodexAccount: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var snapshotFileName: String
    var createdAt: Date
    var updatedAt: Date
    var email: String?
    var planType: String?
    var rateLimits: CodexRateLimitSnapshot?
}
