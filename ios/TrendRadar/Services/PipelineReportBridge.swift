import Foundation

/// Bridges pipeline execution output with local report storage.
enum PipelineReportBridge {
    static func persist(_ report: ReportDetail?) async {
        guard let report else { return }
        await ReportStore.shared.save(report)
    }
}
