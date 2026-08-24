import Foundation

/// Bridges pipeline execution output with local report storage.
enum PipelineReportBridge {
    static func persist(_ report: ReportDetail?) async throws {
        guard let report else { return }
        try await LocalStore.shared.save(report)
    }
}
