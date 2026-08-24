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
    @Published private(set) var latestAIAnalysis: ReportAIAnalysis?
    @Published private(set) var latestGeneratedReportID: UUID?
    @Published var errorMessage: String?

    private let localStore = LocalStore.shared
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
        if let latest = reports.first {
            latestAIAnalysis = await localStore.loadReport(id: latest.id)?.aiAnalysis
        } else {
            latestAIAnalysis = nil
        }
    }

    func clearCache() async throws {
        try await localStore.clearAll()
        reports = []
        latestAIAnalysis = nil
    }

    func refreshLatestAIAnalysis() async {
        if reports.isEmpty {
            reports = await localStore.loadReportSummaries()
        }
        guard let latest = reports.first else {
            latestAIAnalysis = nil
            return
        }
        latestAIAnalysis = await localStore.loadReport(id: latest.id)?.aiAnalysis
    }

    func applyRetentionPolicy(days: Int) async {
        do {
            try await localStore.applyReportRetention(days: days)
            await load()
        } catch {
            errorMessage = "清理历史报告失败：\(error.localizedDescription)"
        }
    }

    func generate(type: ReportType, settings: AppSettings, items: [NewsItem], hotlistItems: [HotNewsItem] = [], trigger: ReportTrigger = .manual, batchID: String? = nil, windowStart: Date? = nil, diagnostics: ReportDiagnostics? = nil) async {
        guard !items.isEmpty || !hotlistItems.isEmpty else {
            errorMessage = "暂无可生成报告的数据，请先完成一次采集。"
            return
        }
        let resolvedBatchID = batchID ?? "manual:\(UUID().uuidString)"
        guard !completedBatches.contains(resolvedBatchID) else { return }
        guard !isGenerating else { return }
        isGenerating = true
        errorMessage = nil
        latestGeneratedReportID = nil
        defer { isGenerating = false }
        let request = ReportGenerationRequest(batchID: resolvedBatchID, type: type, trigger: trigger, generatedAt: Date(), settings: settings, windowStart: windowStart, newItemIDs: [], diagnostics: diagnostics)
        do {
            var report = generator.generate(request: request, items: items, hotlistItems: hotlistItems)
            // AI 报告生产不应受页面展示开关影响；展示开关只控制 UI 是否显示。
            if settings.ai.enabled && settings.aiAnalysis.enabled {
                let snapshotHotlist = report.sections.flatMap(\.items).filter { $0.sourceType == .hotlist }.map { snapshot in
                    HotNewsItem(id: snapshot.id, title: snapshot.title, url: snapshot.url, platformID: snapshot.source, platformName: snapshot.source, rank: snapshot.rank ?? 0, publishedAt: snapshot.publishedAt, extraInfo: snapshot.summary, topicKey: snapshot.title, previousRank: nil, isRead: snapshot.isRead, isFavorite: snapshot.isFavorite)
                }
                let snapshotRSS = report.sections.flatMap(\.items).filter { $0.sourceType == .rss }.map { snapshot in
                    NewsItem(id: snapshot.id, title: snapshot.title, source: snapshot.source, url: snapshot.url, publishedAt: snapshot.publishedAt, summary: snapshot.summary, isRead: snapshot.isRead, isFavorite: snapshot.isFavorite)
                }
                let standaloneContent = aiService.standaloneContent(hotlistItems: snapshotHotlist, rssItems: snapshotRSS, settings: settings)
                report.aiAnalysis = await aiService.reportAnalysis(hotlistItems: snapshotHotlist, rssItems: snapshotRSS, settings: settings, reportType: type.displayName, standaloneContent: standaloneContent)
                report.aiAnalysis?.citations = report.sections.flatMap(\.items).compactMap { item in
                    InsightCitation(itemID: item.id, title: item.title, source: item.source, url: item.url)
                }
            }
            try await localStore.save(report)
            latestGeneratedReportID = report.id
            latestAIAnalysis = report.aiAnalysis
            completedBatches.insert(resolvedBatchID)
            let delivery = await ReportDeliveryService().deliver(report: report, settings: settings)
            if let message = delivery.failureMessage {
                errorMessage = "报告已保存，但通知渠道投递失败：\(message)"
            }
            await load()
        } catch {
            errorMessage = "报告保存失败：\(error.localizedDescription)"
        }
    }

    func latestGeneratedDetail() async -> ReportDetail? {
        guard let latestGeneratedReportID else { return nil }
        return await localStore.loadReport(id: latestGeneratedReportID)
    }

    func detail(id: UUID) async -> ReportDetail? {
        await localStore.loadReport(id: id)
    }

    /// 为已经保存但尚未完成 AI 分析的报告补生成，并写回同一份报告。
    func generateAIAnalysis(for reportID: UUID, settings: AppSettings) async {
        guard !isGenerating else { return }
        guard var report = await localStore.loadReport(id: reportID) else {
            errorMessage = "找不到要分析的报告。"
            return
        }
        guard settings.ai.enabled && settings.aiAnalysis.enabled else {
            errorMessage = "请同时开启 AI 分析和结构化报告分析。"
            return
        }
        isGenerating = true
        defer { isGenerating = false }
        let snapshots = report.sections.flatMap(\.items)
        let hotlist = snapshots.filter { $0.sourceType == .hotlist }.map { snapshot in
            HotNewsItem(id: snapshot.id, title: snapshot.title, url: snapshot.url, platformID: snapshot.source, platformName: snapshot.source, rank: snapshot.rank ?? 0, publishedAt: snapshot.publishedAt, extraInfo: snapshot.summary, topicKey: snapshot.title, previousRank: nil, isRead: snapshot.isRead, isFavorite: snapshot.isFavorite)
        }
        let rss = snapshots.filter { $0.sourceType == .rss }.map { snapshot in
            NewsItem(id: snapshot.id, title: snapshot.title, source: snapshot.source, url: snapshot.url, publishedAt: snapshot.publishedAt, summary: snapshot.summary, isRead: snapshot.isRead, isFavorite: snapshot.isFavorite)
        }
        let standalone = aiService.standaloneContent(hotlistItems: hotlist, rssItems: rss, settings: settings)
        report.aiAnalysis = await aiService.reportAnalysis(hotlistItems: hotlist, rssItems: rss, settings: settings, reportType: report.type.displayName, standaloneContent: standalone)
        report.aiAnalysis?.citations = snapshots.map { InsightCitation(itemID: $0.id, title: $0.title, source: $0.source, url: $0.url) }
        do {
            try await localStore.save(report)
            latestAIAnalysis = report.aiAnalysis
            await load()
        } catch {
            errorMessage = "AI 分析已生成，但保存失败：\(error.localizedDescription)"
        }
    }

    func diagnostics(news: NewsStore, hotNews: HotNewsStore) -> ReportDiagnostics? {
        var failures: [ReportSourceFailure] = []
        failures += news.sourceFailures.map { ReportSourceFailure(sourceType: .rss, source: $0, message: news.sourceFailureDetails[$0] ?? "刷新失败") }
        failures += hotNews.sourceFailures.map { ReportSourceFailure(sourceType: .hotlist, source: $0, message: hotNews.sourceFailureDetails[$0] ?? "刷新失败") }
        return failures.isEmpty ? nil : ReportDiagnostics(failures: failures, collectedAt: Date())
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
