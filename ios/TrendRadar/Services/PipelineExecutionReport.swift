import Foundation

struct PipelineExecutionReport: Sendable, Codable {
    let requestID: UUID
    let trigger: PipelineTrigger
    let startedAt: Date
    let finishedAt: Date
    let stageResults: [PipelineStageResult]
    let reportID: String?
    let deliveryStatus: DeliveryStatus

    var duration: TimeInterval {
        finishedAt.timeIntervalSince(startedAt)
    }
}

struct PipelineStageResult: Sendable, Codable {
    let name: String
    let success: Bool
    let message: String?
    let duration: TimeInterval
}

enum DeliveryStatus: String, Sendable, Codable {
    case notAttempted
    case delivered
    case failed
}
