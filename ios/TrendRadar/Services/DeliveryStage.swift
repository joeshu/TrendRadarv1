import Foundation

struct DeliveryStage {
    func execute(report: ReportDetail, settings: AppSettings) async -> ReportDeliveryResult {
        await ReportDeliveryService().deliver(report: report, settings: settings)
    }
}
