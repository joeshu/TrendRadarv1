import Foundation

protocol PipelineStage {
    associatedtype Input
    associatedtype Output

    func execute(_ input: Input) async throws -> Output
}

struct RefreshPipelineContext: Sendable {
    let reason: String
    let startedAt: Date
}

struct RefreshPipelineResult: Sendable {
    let context: RefreshPipelineContext
    let success: Bool
    let message: String?
}
