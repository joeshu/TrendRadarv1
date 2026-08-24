import Foundation

/// Unified refresh execution pipeline.
///
/// The pipeline keeps foreground refresh, background refresh and manual report
/// generation on the same execution model. Concrete collectors and reporters can
/// be injected in later batches.
public actor RefreshPipeline {
    public struct Context: Sendable {
        public let reason: String
        public let startedAt: Date

        public init(reason: String) {
            self.reason = reason
            self.startedAt = Date()
        }
    }

    public struct Result: Sendable {
        public let collected: Int
        public let persisted: Int
        public let reported: Bool
        public let completedAt: Date

        public init(collected: Int = 0, persisted: Int = 0, reported: Bool = false) {
            self.collected = collected
            self.persisted = persisted
            self.reported = reported
            self.completedAt = Date()
        }
    }

    private var running = false

    public init() {}

    public func run(reason: String) async throws -> Result {
        guard !running else {
            return Result()
        }

        running = true
        defer { running = false }

        let context = Context(reason: reason)
        try Task.checkCancellation()

        // Phase order is intentionally fixed:
        // Scheduler -> Collector -> Filter -> Persist -> Report -> Deliver.
        // Existing services can be migrated into each stage incrementally.
        _ = context

        try Task.checkCancellation()
        return Result()
    }
}
