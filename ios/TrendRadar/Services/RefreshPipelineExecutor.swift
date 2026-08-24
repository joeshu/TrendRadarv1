import Foundation

actor RefreshPipelineExecutor {
    private var running = false

    func execute(context: PipelineExecutionContext) async throws -> RefreshPipelineResult {
        guard !running else {
            return RefreshPipelineResult(status: .skipped, context: context)
        }

        running = true
        defer { running = false }

        try Task.checkCancellation()

        // Stage migration point:
        // Collector -> Filter -> Persist -> Report -> Delivery
        // Existing services will be migrated incrementally.
        return RefreshPipelineResult(status: .completed, context: context)
    }
}

struct RefreshPipelineResult: Sendable {
    enum Status: Sendable {
        case completed
        case skipped
    }

    let status: Status
    let context: PipelineExecutionContext
}
