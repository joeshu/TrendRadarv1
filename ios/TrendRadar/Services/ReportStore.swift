import Foundation
import Combine

@MainActor
final class ReportStore: ObservableObject {
    @Published private(set) var reports: [ReportSummary] = []
    @Published var searchText = ""
    @Published var selectedType: ReportType?
    @Published var favoritesOnly = false
    @Published private(set) var isLoading = false
    @Published private(set) var isGenerating = false
    @Published var errorMessage: String?

    private let localStore = LocalStore()
    private let generator = ReportGenerationService()
    private let aiService = AIService()
    private var completedBatches = Set<String>()

    var filteredReports: [ReportSummary] {
        reports.filter { report in
            let matchesType = selectedType == nil || report.type == selectedType
            let matchesFavorite = !favoritesOnly || report.isFavorite
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let searchableText = "\(report.title) \(report.searchableText)"
            let matchesSearch = query.isEmpty || searchableText.localizedCaseInsensitiveContains(query)
            return matchesType && matchesFavorite && matchesSearch
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
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

    func generate(type: ReportType, settings: AppSettings, items: [NewsItem], trigger: ReportTrigger = .manual, batchID: String? = nil) async {
        let resolvedBatchID = batchID ?? "\(type.rawValue):\(items.map(\.id).sorted().joined(separator: ","))"
        guard !completedBatches.contains(resolvedBatchID) else { return }
        guard !isGenerating else { return }
        isGenerating = true
        defer { isGenerating = false }
        let request = ReportGenerationRequest(batchID: resolvedBatchID, type: type, trigger: trigger, generatedAt: Date(), settings: settings)
        do {
            var report = generator.generate(request: request, items: items)
            if settings.aiAnalysis.enabled {
                report.aiAnalysis = await aiService.reportAnalysis(for: items, settings: settings)
            }
            try await localStore.save(report)
            completedBatches.insert(resolvedBatchID)
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
