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

        let persisted = try await PersistStage().execute(filtered)
        try Task.checkCancellation()

        var reportCreated = false
        var deliveryCompleted = false

        if let report = try await ReportStage().execute(items: persisted, settings: settings) {
            reportCreated = true
            let delivery = await DeliveryStage().execute(report: report, settings: settings)
            deliveryCompleted = delivery.failureMessage == nil
        }

        return RefreshPipelineResult(
            status: .completed,
            context: context,
            reportCreated: reportCreated,
            deliveryCompleted: deliveryCompleted
        )
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
    let reportCreated: Bool
    let deliveryCompleted: Bool

    init(
        status: Status,
        context: PipelineExecutionContext,
        reportCreated: Bool = false,
        deliveryCompleted: Bool = false
    ) {
        self.status = status
        self.context = context
        self.reportCreated = reportCreated
        self.deliveryCompleted = deliveryCompleted
    }
}
