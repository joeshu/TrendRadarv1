import Foundation
import Combine
import UserNotifications

@MainActor
final class NewsStore: ObservableObject {
    @Published private(set) var items: [NewsItem] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastUpdated: Date?
    @Published var errorMessage: String?

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

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        errorMessage = nil
        defer { isRefreshing = false }

        do {
            let crawler = self.crawler
            let results = try await withThrowingTaskGroup(of: [NewsItem].self) { group in
                for feed in feeds where settings.rssEnabled && settings.customFeeds.first(where: { $0.id == feed.id })?.isEnabled == true {
                    group.addTask { try await crawler.fetch(feed: feed) }
                }
                return try await group.reduce(into: []) { $0.append(contentsOf: $1) }
            }
            let oldByID = items.reduce(into: [String: NewsItem]()) { $0[$1.id] = $1 }
            let uniqueResults = results.reduce(into: [String: NewsItem]()) { $0[$1.id] = $1 }.values
            let filteredResults = uniqueResults.filter { matchesConfiguredFilters($0) }
            let refreshedItems = filteredResults.map { item in
                var updated = item
                updated.isRead = oldByID[item.id]?.isRead ?? false
                updated.isFavorite = oldByID[item.id]?.isFavorite ?? false
                return updated
            }
            let refreshedIDs = Set(refreshedItems.map(\.id))
            items = refreshedItems + items.filter { !refreshedIDs.contains($0.id) }
            await localStore.save(items)
            lastUpdated = Date()
            if settings.scheduleEnabled {
                await generateReport(trigger: .foregroundRefresh)
            }
        } catch {
            errorMessage = "刷新失败：\(error.localizedDescription)"
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

    private func generateReport(trigger: ReportTrigger) async {
        guard let type = ReportType(rawValue: settings.report.mode) else { return }
        let request = ReportGenerationRequest(batchID: "\(trigger.rawValue):\(items.map(\.id).sorted().joined(separator: ","))", type: type, trigger: trigger, generatedAt: Date(), settings: settings)
        let report = ReportGenerationService().generate(request: request, items: items)
        try? await localStore.save(report)
    }

    private func matchesConfiguredFilters(_ item: NewsItem) -> Bool {
        guard KeywordRuleSet(keywords: settings.keywords, globalExcluded: settings.globalFilterWords).matches(item.title) else { return false }
        guard settings.rssFreshnessEnabled, settings.rssMaxAgeDays > 0, let publishedAt = item.publishedAt else { return true }
        return publishedAt >= Date(timeIntervalSinceNow: -Double(settings.rssMaxAgeDays) * 86_400)
    }
}
