import Foundation

actor RefreshPipelineExecutor {
    static let shared = RefreshPipelineExecutor()

    private var running = false

    func execute(context: PipelineExecutionContext) async throws -> RefreshPipelineExecutionResult {
        guard !running else {
            return RefreshPipelineExecutionResult(status: .skipped, context: context)
        }

        running = true
        defer { running = false }

        var stageResults: [PipelineStageResult] = []
        var reportID: String?
        var deliveryStatus: DeliveryStatus = .notAttempted

        do {
            try Task.checkCancellation()

            let settings = loadSettings()
            let input = RefreshPipelineInput(
                settings: settings,
                trigger: context.trigger
            )

            let collected = try await runStage("collector", results: &stageResults) {
                try await CollectorStage().execute(input)
            }
            try Task.checkCancellation()

            let filtered = try await runStage("filter", results: &stageResults) {
                try await FilterStage().execute(collected)
            }
            try Task.checkCancellation()

            let persisted = try await runStage("persist", results: &stageResults) {
                try await PersistStage().execute(filtered)
            }
            try Task.checkCancellation()

            let report = try await runStage("report", results: &stageResults) {
                try await ReportStage().execute(items: persisted, settings: settings)
            }
            if let report {
                await PipelineReportBridge.persist(report)
                reportID = report.id.uuidString
                let deliveryStartedAt = Date()
                let delivery = await DeliveryStage().execute(report: report, settings: settings)
                let deliveryMessage = delivery.failureMessage
                deliveryStatus = deliveryMessage == nil ? .delivered : .failed
                stageResults.append(PipelineStageResult(
                    name: "delivery",
                    success: deliveryMessage == nil,
                    message: deliveryMessage,
                    duration: Date().timeIntervalSince(deliveryStartedAt)
                ))
            }

            let executionReport = makeReport(
                context: context,
                stageResults: stageResults,
                reportID: reportID,
                deliveryStatus: deliveryStatus
            )
            await PipelineDiagnosticsStore.shared.save(executionReport)

            return RefreshPipelineExecutionResult(
                status: .completed,
                context: context,
                reportCreated: reportID != nil,
                deliveryCompleted: deliveryStatus == .delivered
            )
        } catch {
            let executionReport = makeReport(
                context: context,
                stageResults: stageResults,
                reportID: reportID,
                deliveryStatus: deliveryStatus
            )
            await PipelineDiagnosticsStore.shared.save(executionReport)
            throw error
        }
    }

    private func loadSettings() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: "trendradar.settings"),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }

    private func runStage<Output>(
        _ name: String,
        results: inout [PipelineStageResult],
        operation: () async throws -> Output
    ) async throws -> Output {
        let startedAt = Date()
        do {
            let output = try await operation()
            results.append(PipelineStageResult(
                name: name,
                success: true,
                message: nil,
                duration: Date().timeIntervalSince(startedAt)
            ))
            return output
        } catch {
            results.append(PipelineStageResult(
                name: name,
                success: false,
                message: error.localizedDescription,
                duration: Date().timeIntervalSince(startedAt)
            ))
            throw error
        }
    }

    private func makeReport(
        context: PipelineExecutionContext,
        stageResults: [PipelineStageResult],
        reportID: String?,
        deliveryStatus: DeliveryStatus
    ) -> PipelineExecutionReport {
        PipelineExecutionReport(
            requestID: context.requestID,
            trigger: context.trigger,
            startedAt: context.startedAt,
            finishedAt: Date(),
            stageResults: stageResults,
            reportID: reportID,
            deliveryStatus: deliveryStatus
        )
    }
}

struct RefreshPipelineExecutionResult: Sendable {
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
