import Foundation

struct PipelineExecutionContext: Sendable {
    let trigger: RefreshTrigger
    let startedAt: Date
    let requestID: UUID

    init(trigger: RefreshTrigger) {
        self.trigger = trigger
        self.startedAt = Date()
        self.requestID = UUID()
    }
}

enum RefreshTrigger: String, Sendable, Codable {
    case foreground
    case background
    case manual
}
