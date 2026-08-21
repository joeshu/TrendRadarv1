import Foundation
import Combine
import UserNotifications

@MainActor
final class NewsStore: ObservableObject {
    @Published private(set) var items: [NewsItem] = []
    @Published private(set) var isRefreshing = false
    @Published var errorMessage: String?

    private let localStore = LocalStore()
    private let crawler = NewsCrawler()
    private let aiService = AIService()
    let feeds = [
        RSSFeed(id: "hn", name: "Hacker News", url: URL(string: "https://news.ycombinator.com/rss")!),
        RSSFeed(id: "bbc", name: "BBC News", url: URL(string: "https://feeds.bbci.co.uk/news/rss.xml")!),
        RSSFeed(id: "nasa", name: "NASA", url: URL(string: "https://www.nasa.gov/rss/dyn/breaking_news.rss")!)
    ]

    var settings: AppSettings = AppSettings()

    func load() async {
        items = await localStore.load()
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        errorMessage = nil
        defer { isRefreshing = false }

        do {
            let crawler = self.crawler
            let results = try await withThrowingTaskGroup(of: [NewsItem].self) { group in
                for feed in feeds where settings.enabledFeedIDs.contains(feed.id) {
                    group.addTask { try await crawler.fetch(feed: feed) }
                }
                return try await group.reduce(into: []) { $0.append(contentsOf: $1) }
            }
            let oldByID = items.reduce(into: [String: NewsItem]()) { $0[$1.id] = $1 }
            let uniqueResults = results.reduce(into: [String: NewsItem]()) { $0[$1.id] = $1 }.values
            let refreshedItems = uniqueResults.map { item in
                var updated = item
                updated.isRead = oldByID[item.id]?.isRead ?? false
                updated.isFavorite = oldByID[item.id]?.isFavorite ?? false
                return updated
            }
            let refreshedIDs = Set(refreshedItems.map(\.id))
            items = refreshedItems + items.filter { !refreshedIDs.contains($0.id) }
            await localStore.save(items)
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
            items[index].summary = try await aiService.summarize(items[index])
            await localStore.save(items)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestNotifications() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }
}
