import Foundation
import Combine

@MainActor
final class ReportStore: ObservableObject {
    @Published private(set) var reports: [ReportSummary] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isGenerating = false
    @Published var errorMessage: String?

    private let localStore = LocalStore()
    private let generator = ReportGenerationService()

    func load() async {
        reports = await localStore.loadReportSummaries()
    }

    func applyRetentionPolicy(days: Int) async {
        do {
            try await localStore.applyReportRetention(days: days)
            await load()
        } catch {
            errorMessage = "清理历史报告失败：\(error.localizedDescription)"
        }
    }

    func generate(type: ReportType, settings: AppSettings, items: [NewsItem], trigger: ReportTrigger = .manual) async {
        guard !isGenerating else { return }
        isGenerating = true
        defer { isGenerating = false }
        let request = ReportGenerationRequest(type: type, trigger: trigger, generatedAt: Date(), settings: settings)
        do {
            let report = generator.generate(request: request, items: items)
            try await localStore.save(report)
            await load()
        } catch {
            errorMessage = "报告保存失败：\(error.localizedDescription)"
        }
    }

    func detail(id: UUID) async -> ReportDetail? {
        await localStore.loadReport(id: id)
    }

    func toggleFavorite(id: UUID) async {
        do {
            try await localStore.toggleReportFavorite(id: id)
            await load()
        } catch {
            errorMessage = "更新报告收藏失败：\(error.localizedDescription)"
        }
    }

    func delete(id: UUID) async {
        do {
            try await localStore.deleteReport(id: id)
            await load()
        } catch {
            errorMessage = "删除报告失败：\(error.localizedDescription)"
        }
    }
}
