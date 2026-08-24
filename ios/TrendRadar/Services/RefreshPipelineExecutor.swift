import Foundation

actor RefreshPipelineExecutor {
    static let shared = RefreshPipelineExecutor()

    private var running = false

    func execute(context: PipelineExecutionContext) async throws -> RefreshPipelineResult {
        guard !running else {
            return RefreshPipelineResult(status: .skipped, context: context)
        }

        running = true
        defer { running = false }

        try Task.checkCancellation()

        let settings = loadSettings()
        let input = RefreshPipelineInput(
            settings: settings,
            trigger: context.trigger
        )

        let collected = try await CollectorStage().execute(input)
        try Task.checkCancellation()

        let filtered = try await FilterStage().execute(collected)
        try Task.checkCancellation()

        _ = try await PersistStage().execute(filtered)

        return RefreshPipelineResult(status: .completed, context: context)
    }

    private func loadSettings() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: "trendradar.settings"),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
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
