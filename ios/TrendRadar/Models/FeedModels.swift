import Foundation

struct FeedHealth: Codable, Equatable, Sendable, Identifiable {
    let sourceID: String
    var consecutiveFailures: Int
    var lastSuccessAt: Date?
    var lastFailureAt: Date?
    var lastError: String?

    var id: String { sourceID }
    var isHealthy: Bool { consecutiveFailures < 3 }
    var shouldShowWarning: Bool { consecutiveFailures >= 3 }
}
