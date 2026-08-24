import Foundation

actor RefreshPipelineCoordinator {
    static let shared = RefreshPipelineCoordinator()

    private var running = false

    func run(reason: String = "manual") async -> RefreshPipelineResult {
        guard !running else {
            return RefreshPipelineResult(
                context: RefreshPipelineContext(reason: reason, startedAt: Date()),
                success: false,
                message: "refresh already running"
            )
        }

        running = true
        defer { running = false }

        let context = RefreshPipelineContext(reason: reason, startedAt: Date())

        do {
            try Task.checkCancellation()
            // Subsequent migrations move collection, filtering, persistence,
            // report generation and delivery into independent stages.
            return RefreshPipelineResult(
                context: context,
                success: true,
                message: "pipeline ready"
            )
        } catch {
            return RefreshPipelineResult(
                context: context,
                success: false,
                message: error.localizedDescription
            )
        }
    }
}
