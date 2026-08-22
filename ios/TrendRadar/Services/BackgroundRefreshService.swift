import BackgroundTasks
import Foundation
import UserNotifications

enum BackgroundRefreshService {
    static let identifier = "com.trendradar.mobile.refresh"

    static func schedule(after interval: TimeInterval = 3600, enabled: Bool = true) {
        guard enabled else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
            return
        }
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
        let settings = loadSettings()
        do {
            guard settings.scheduleEnabled else {
                task.setTaskCompleted(success: true)
                return
            }
            let preset = TimelineCatalog.preset(for: settings.schedulePreset)
            let calendar = Calendar.trendRadar(timeZoneIdentifier: settings.timezone)
            let match = preset.match(at: Date(), calendar: calendar)
            let timelineAction = TimelineExecutionStore().claim(presetID: preset.id, periodID: match.periodID, action: match.action, calendar: calendar)
            guard timelineAction.collect else {
                schedule(after: settings.refreshInterval * 60, enabled: settings.scheduleEnabled)
                task.setTaskCompleted(success: true)
                return
            }
            let feeds = settings.customFeeds.compactMap(\.rssFeed)
            let crawler = NewsCrawler()
            var freshItems: [NewsItem] = []
            for feed in feeds where settings.rssEnabled && settings.customFeeds.first(where: { $0.id == feed.id })?.isEnabled == true {
                try Task.checkCancellation()
                freshItems.append(contentsOf: try await crawler.fetch(feed: feed))
            }
            try Task.checkCancellation()
            if !settings.keywords.isEmpty {
                freshItems = freshItems.filter { item in
                    settings.keywords.contains { item.title.localizedCaseInsensitiveContains($0) }
                }
            }
            freshItems = freshItems.filter { item in
                !settings.globalFilterWords.contains { item.title.localizedCaseInsensitiveContains($0) }
            }
            if settings.rssFreshnessEnabled {
                freshItems = freshItems.filter { item in
                    let feedAge = settings.customFeeds.first { $0.name == item.source }?.maxAgeDays ?? 0
                    let maxAgeDays = feedAge > 0 ? feedAge : settings.rssMaxAgeDays
                    guard maxAgeDays > 0 else { return true }
                    let cutoff = Date(timeIntervalSinceNow: -Double(maxAgeDays) * 86_400)
                    return item.publishedAt.map { $0 >= cutoff } ?? true
                }
            }
            if settings.ai.enabled, settings.ai.filterMethod == "ai", !settings.ai.interests.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                do {
                    freshItems = try await AIService().filter(freshItems, settings: settings)
                } catch {
                    // Keep keyword-filtered items when AI is unavailable.
                }
            }
            let localStore = LocalStore()
            let oldItems = await localStore.load()
            let hotlistItems = await localStore.loadHotNews()
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
            if settings.scheduleEnabled, timelineAction.push, let reportType = ReportType(rawValue: timelineAction.reportMode.rawValue) {
                let batchID = "backgroundRefresh:\(merged.map(\.id).sorted().joined(separator: ","))"
                let request = ReportGenerationRequest(batchID: batchID, type: reportType, trigger: .backgroundRefresh, generatedAt: Date(), settings: settings)
                var report = ReportGenerationService().generate(request: request, items: merged, hotlistItems: hotlistItems)
                if timelineAction.analyze {
                    report.aiAnalysis = await AIService().reportAnalysis(hotlistItems: hotlistItems, rssItems: merged, settings: settings, reportType: reportType.displayName)
                }
                try Task.checkCancellation()
                try? await localStore.save(report)
            }
            let newCount = freshItems.filter { !oldIDs.contains($0.id) }.count
            if newCount > 0 && timelineAction.push && settings.notification.enabled && settings.notification.localAlerts {
                await notify(newCount: newCount, soundEnabled: settings.notification.soundEnabled)
            }
            schedule(after: settings.refreshInterval * 60, enabled: settings.scheduleEnabled)
            task.setTaskCompleted(success: true)
        } catch {
            schedule(after: 3600, enabled: settings.scheduleEnabled)
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

    private static func notify(newCount: Int, soundEnabled: Bool) async {
        let content = UNMutableNotificationContent()
        content.title = "TrendRadar"
        content.body = "发现 \(newCount) 条新热点"
        content.sound = soundEnabled ? .default : nil
        let request = UNNotificationRequest(identifier: "new-news", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
