import Foundation

struct DeliveryStage {
    func execute(report: Report, settings: AppSettings) async -> ReportDeliveryResult {
        await ReportDeliveryService().deliver(report: report, settings: settings)
    }
}
