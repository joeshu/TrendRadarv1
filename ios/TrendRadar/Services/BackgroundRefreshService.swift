import BackgroundTasks
import Foundation
import UserNotifications

enum BackgroundRefreshService {
    static let identifier = "com.trendradar.mobile.refresh"

    static func schedule(after interval: TimeInterval = 3600) {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: interval)
        try? BGTaskScheduler.shared.submit(request)
    }

    static func run(task: BGAppRefreshTask) async {
        let work = Task {
            await refresh(task: task)
        }
        task.expirationHandler = {
            work.cancel()
        }
        await work.value
    }

    private static func refresh(task: BGAppRefreshTask) async {
        do {
            let settings = loadSettings()
            let feeds = [
                RSSFeed(id: "hn", name: "Hacker News", url: URL(string: "https://news.ycombinator.com/rss")!),
                RSSFeed(id: "bbc", name: "BBC News", url: URL(string: "https://feeds.bbci.co.uk/news/rss.xml")!),
                RSSFeed(id: "nasa", name: "NASA", url: URL(string: "https://www.nasa.gov/rss/dyn/breaking_news.rss")!)
            ]
            let crawler = NewsCrawler()
            var freshItems: [NewsItem] = []
            for feed in feeds where settings.enabledFeedIDs.contains(feed.id) {
                try Task.checkCancellation()
                freshItems.append(contentsOf: try await crawler.fetch(feed: feed))
            }
            try Task.checkCancellation()
            if !settings.keywords.isEmpty {
                freshItems = freshItems.filter { item in
                    settings.keywords.contains { item.title.localizedCaseInsensitiveContains($0) }
                }
            }
            let localStore = LocalStore()
            let oldItems = await localStore.load()
            let oldByID = oldItems.reduce(into: [String: NewsItem]()) { $0[$1.id] = $1 }
            let oldIDs = Set(oldByID.keys)
            let refreshedItems = freshItems.reduce(into: [String: NewsItem]()) { result, item in
                var updated = item
                updated.isRead = oldByID[item.id]?.isRead ?? false
                updated.isFavorite = oldByID[item.id]?.isFavorite ?? false
                result[item.id] = updated
            }.values
            var merged = Array(refreshedItems)
            merged.append(contentsOf: oldItems.filter { old in !freshItems.contains(where: { $0.id == old.id }) })
            await localStore.save(merged)
            try Task.checkCancellation()
            let newCount = freshItems.filter { !oldIDs.contains($0.id) }.count
            if newCount > 0 { await notify(newCount: newCount) }
            schedule(after: settings.refreshInterval * 60)
            task.setTaskCompleted(success: true)
        } catch {
            schedule(after: 3600)
            task.setTaskCompleted(success: false)
        }
    }

    private static func loadSettings() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: "trendradar.settings"),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }

    private static func notify(newCount: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "TrendRadar"
        content.body = "发现 \(newCount) 条新热点"
        content.sound = .default
        let request = UNNotificationRequest(identifier: "new-news", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
