import Foundation

/// Stores the latest pipeline execution report for diagnostics and recovery flows.
actor PipelineDiagnosticsStore {
    static let shared = PipelineDiagnosticsStore()

    private let key = "trendradar.pipeline.lastExecution"

    func save(_ report: PipelineExecutionReport) {
        guard let data = try? JSONEncoder().encode(report) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    func load() -> PipelineExecutionReport? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PipelineExecutionReport.self, from: data)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
