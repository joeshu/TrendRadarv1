import Foundation

struct ReportStage {
    func execute(items: [NewsItem], settings: AppSettings) async throws -> ReportDetail? {
        try Task.checkCancellation()
        let request = ReportGenerationRequest(batchID: UUID().uuidString, type: .daily, trigger: .backgroundRefresh, generatedAt: Date(), settings: settings)
        return ReportGenerationService().generate(request: request, items: items, hotlistItems: [])
    }
}
