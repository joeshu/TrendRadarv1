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
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Background scheduling is optional and must never affect foreground launch.
        }
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
            let filterEngine = FilterEngine(settings: settings)
            freshItems = freshItems.filter { filterEngine.includes($0) }
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
            let localStore = LocalStore.shared
            let oldItems = await localStore.load()
            let oldHotlistItems = await localStore.loadHotNews()
            let hotlistItems = await refreshHotlist(settings: settings, previous: oldHotlistItems, localStore: localStore)
            let oldByID = oldItems.reduce(into: [String: NewsItem]()) { $0[$1.id] = $1 }
            let oldIDs = Set(oldByID.keys)
            let refreshedItems = freshItems.reduce(into: [String: NewsItem]()) { result, item in
                var updated = item
                updated.isRead = oldByID[item.id]?.isRead ?? false
                updated.isFavorite = oldByID[item.id]?.isFavorite ?? false
                result[item.id] = updated
            }.values
            var merged = Array(refreshedItems)
            let enabledSourceNames = Set(feeds.filter { feed in
                settings.customFeeds.first(where: { $0.id == feed.id })?.isEnabled == true
            }.map(\.name))
            merged.append(contentsOf: oldItems.filter { old in
                enabledSourceNames.contains(old.source) && !freshItems.contains(where: { $0.id == old.id })
            })
            await localStore.save(merged)
            try Task.checkCancellation()
            if settings.scheduleEnabled, timelineAction.push, let reportType = ReportType(rawValue: timelineAction.reportMode.rawValue) {
                let batchID = "backgroundRefresh:\(merged.map(\.id).sorted().joined(separator: ","))"
                let request = ReportGenerationRequest(batchID: batchID, type: reportType, trigger: .backgroundRefresh, generatedAt: Date(), settings: settings)
                var report = ReportGenerationService().generate(request: request, items: merged, hotlistItems: hotlistItems)
                if timelineAction.analyze {
                    let aiService = AIService()
                    let standaloneContent = aiService.standaloneContent(hotlistItems: hotlistItems, rssItems: merged, settings: settings)
                    report.aiAnalysis = await aiService.reportAnalysis(hotlistItems: hotlistItems, rssItems: merged, settings: settings, reportType: reportType.displayName, standaloneContent: standaloneContent)
                    report.aiAnalysis?.citations = report.sections.flatMap(\.items).compactMap { item in
                        InsightCitation(itemID: item.id, title: item.title, source: item.source, url: item.url)
                    }
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

    private static func refreshHotlist(settings: AppSettings, previous: [HotNewsItem], localStore: LocalStore) async -> [HotNewsItem] {
        guard settings.platformsEnabled else { return [] }
        let enabledSources = settings.platformSources.filter(\.isEnabled)
        guard !enabledSources.isEmpty else { return previous }
        let baseURL = settings.platformAPIURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "https://newsnow.busiyi.world/api"
            : settings.platformAPIURL
        let service = NewsNowService()
        let results = await withTaskGroup(of: (PlatformSource, [HotNewsItem]).self) { group in
            for source in enabledSources {
                group.addTask {
                    do {
                        return (source, try await service.fetch(sourceID: source.id, sourceName: source.name, expectedDomain: source.expectedDomain, baseURL: baseURL))
                    } catch {
                        return (source, [])
                    }
                }
            }
            return await group.reduce(into: [(PlatformSource, [HotNewsItem])]()) { $0.append($1) }
        }
        let successful = results.filter { !$0.1.isEmpty }
        guard !successful.isEmpty else { return previous }
        let previousByID = previous.reduce(into: [String: HotNewsItem]()) { $0[$1.id] = $1 }
        let fetched = successful.flatMap(\.1).map { item in
            var updated = item
            updated.previousRank = previousByID[item.id]?.rank
            updated.isRead = previousByID[item.id]?.isRead ?? false
            updated.isFavorite = previousByID[item.id]?.isFavorite ?? false
            return updated
        }
        let successfulIDs = Set(successful.map { $0.0.id })
        let failedCached = previous.filter { !successfulIDs.contains($0.platformID) }
        let merged = (fetched + failedCached).sorted { $0.rank < $1.rank }
        try? await localStore.saveHotNews(merged, replacingPlatformIDs: successfulIDs)
        return merged
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
