import Foundation

struct ReportDeliveryResult: Equatable, Sendable {
    let succeeded: Bool
    let failureMessage: String?

    static let skipped = ReportDeliveryResult(succeeded: true, failureMessage: nil)
}

/// Single report delivery entry point shared by foreground, background and
/// manual generation. Channel-specific payload formatting remains isolated in
/// GenericWebhookService.
struct ReportDeliveryService: Sendable {
    func deliver(report: ReportDetail, settings: AppSettings) async -> ReportDeliveryResult {
        guard settings.notification.enabled else { return .skipped }
        let succeeded = await GenericWebhookService().sendConfiguredChannels(report: report, settings: settings)
        guard !succeeded else { return ReportDeliveryResult(succeeded: true, failureMessage: nil) }
        let failure = GenericWebhookService.records().first { record in
            record.reportID == report.id.uuidString && !record.success
        }
        return ReportDeliveryResult(
            succeeded: false,
            failureMessage: failure?.message ?? "通知渠道投递失败"
        )
    }
}
