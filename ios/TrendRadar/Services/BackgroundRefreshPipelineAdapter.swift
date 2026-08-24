import Foundation

/// Adapter used by BackgroundRefreshService to delegate business execution
/// into the unified refresh pipeline.
enum BackgroundRefreshPipelineAdapter {
    static func execute(trigger: RefreshTrigger = .background) async throws -> RefreshPipelineExecutionResult {
        let context = PipelineExecutionContext(trigger: trigger)
        return try await RefreshPipelineExecutor.shared.execute(context: context)
    }
}
