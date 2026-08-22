import Foundation
import Combine
import UserNotifications

@MainActor
final class NewsStore: ObservableObject {
    @Published private(set) var items: [NewsItem] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastUpdated: Date?
    @Published var errorMessage: String?
    @Published private(set) var sourceFailures: [String] = []

    private let localStore = LocalStore()
    private let crawler = NewsCrawler()
    private let aiService = AIService()
    var settings: AppSettings = AppSettings()

    var feeds: [RSSFeed] {
        settings.customFeeds.compactMap(\.rssFeed)
    }

    func load() async {
        items = await localStore.load()
        lastUpdated = items.compactMap(\.publishedAt).max()
    }

    func clearCache() async throws {
        try await localStore.clearAll()
        items = []
        lastUpdated = nil
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        errorMessage = nil
        sourceFailures = []
        defer { isRefreshing = false }

        do {
            guard settings.rssEnabled else {
                items = []
                lastUpdated = nil
                return
            }
            let enabledFeeds = feeds.filter { feed in
                settings.customFeeds.first(where: { $0.id == feed.id })?.isEnabled == true
            }
            guard !enabledFeeds.isEmpty else {
                items = []
                lastUpdated = nil
                errorMessage = "请先在订阅中启用至少一个 RSS 源"
                return
            }
            let crawler = self.crawler
            let results = await withTaskGroup(of: (String, [NewsItem]).self) { group in
                for feed in enabledFeeds {
                    group.addTask {
                        do {
                            return (feed.name, try await crawler.fetch(feed: feed))
                        } catch {
                            return (feed.name, [])
                        }
                    }
                }
                return await group.reduce(into: [(String, [NewsItem]) ]()) { result, value in
                    result.append(value)
                }
            }
            sourceFailures = results.filter { $0.1.isEmpty }.map(\.0).sorted()
            let successfulResults = results.filter { !$0.1.isEmpty }
            guard !successfulResults.isEmpty else {
                throw URLError(.cannotLoadFromNetwork)
            }
            let oldByID = items.reduce(into: [String: NewsItem]()) { $0[$1.id] = $1 }
            let fetchedItems = successfulResults.flatMap(\.1)
            let uniqueResults = fetchedItems.reduce(into: [String: NewsItem]()) { $0[$1.id] = $1 }.values
            var filteredResults = uniqueResults.filter { matchesConfiguredFilters($0) }
            if settings.ai.enabled, settings.ai.filterMethod == "ai", !settings.ai.interests.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                do {
                    filteredResults = try await aiService.filter(Array(filteredResults), settings: settings)
                } catch {
                    errorMessage = "AI 筛选失败，已保留关键词筛选结果：\(error.localizedDescription)"
                }
            }
            let refreshedItems = filteredResults.map { item in
                var updated = item
                updated.isRead = oldByID[item.id]?.isRead ?? false
                updated.isFavorite = oldByID[item.id]?.isFavorite ?? false
                return updated
            }
            let refreshedIDs = Set(refreshedItems.map(\.id))
            let enabledSourceNames = Set(enabledFeeds.map(\.name))
            items = refreshedItems + items.filter {
                enabledSourceNames.contains($0.source) && !refreshedIDs.contains($0.id)
            }
            await localStore.save(items)
            lastUpdated = Date()
            if !sourceFailures.isEmpty {
                errorMessage = "部分 RSS 源刷新失败：\(sourceFailures.joined(separator: "、"))"
            }
            let preset = TimelineCatalog.preset(for: settings.schedulePreset)
            let calendar = Calendar.trendRadar(timeZoneIdentifier: settings.timezone)
            let match = preset.match(at: Date(), calendar: calendar)
            let timelineAction = TimelineExecutionStore().claim(presetID: preset.id, periodID: match.periodID, action: match.action, calendar: calendar)
            if settings.scheduleEnabled, timelineAction.push {
                await generateReport(trigger: .foregroundRefresh, type: timelineAction.reportMode)
            }
        } catch {
            errorMessage = sourceFailures.isEmpty
                ? "刷新失败：\(error.localizedDescription)"
                : "RSS 刷新失败：\(sourceFailures.joined(separator: "、"))"
        }
    }

    func updateSettings(_ value: AppSettings) async {
        settings = value
        await refresh()
    }

    func toggleFavorite(_ item: NewsItem) async {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isFavorite.toggle()
        await localStore.save(items)
    }

    func markRead(_ item: NewsItem) async {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isRead = true
        await localStore.save(items)
    }

    func summarize(_ item: NewsItem) async {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        do {
            items[index].summary = try await aiService.summarize(items[index], settings: settings)
            await localStore.save(items)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestNotifications() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    private func generateReport(trigger: ReportTrigger, type: ReportType? = nil) async {
        guard let type = type ?? ReportType(rawValue: settings.report.mode) else { return }
        let hotlistItems = await localStore.loadHotNews()
        let allIDs = (items.map(\.id) + hotlistItems.map(\.id)).sorted().joined(separator: ",")
        let request = ReportGenerationRequest(batchID: "\(trigger.rawValue):\(allIDs)", type: type, trigger: trigger, generatedAt: Date(), settings: settings)
        var report = ReportGenerationService().generate(request: request, items: items, hotlistItems: hotlistItems)
        if settings.aiAnalysis.enabled && settings.display.showAIAnalysis {
            report.aiAnalysis = await aiService.reportAnalysis(hotlistItems: hotlistItems, rssItems: items, settings: settings, reportType: type.displayName)
        }
        try? await localStore.save(report)
    }

    private func matchesConfiguredFilters(_ item: NewsItem) -> Bool {
        guard KeywordRuleSet(keywords: settings.keywords, globalExcluded: settings.globalFilterWords).matches(item.title) else { return false }
        guard settings.rssFreshnessEnabled, let publishedAt = item.publishedAt else { return true }
        let feedAge = settings.customFeeds.first { $0.name == item.source }?.maxAgeDays ?? 0
        let maxAgeDays = feedAge > 0 ? feedAge : settings.rssMaxAgeDays
        guard maxAgeDays > 0 else { return true }
        return publishedAt >= Date(timeIntervalSinceNow: -Double(maxAgeDays) * 86_400)
    }
}
