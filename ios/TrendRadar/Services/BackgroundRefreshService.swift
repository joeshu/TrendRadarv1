import BackgroundTasks
import Foundation
import UserNotifications

enum BackgroundRefreshService {
    static let identifier = "com.trendradar.mobile.refresh"

    static var isSupportedHost: Bool {
        isSupportedHost(
            processName: ProcessInfo.processInfo.processName,
            bundlePath: Bundle.main.bundleURL.path
        )
    }

    static func isSupportedHost(processName: String, bundlePath: String) -> Bool {
        let normalizedProcessName = processName.lowercased()
        let normalizedBundlePath = bundlePath.lowercased()
        let isLiveContainer = normalizedProcessName.hasPrefix("liveprocess")
            || normalizedBundlePath.contains("/documents/applications/")
        return !isLiveContainer && normalizedBundlePath.hasSuffix(".app")
    }

    @discardableResult
    static func register() -> Bool {
        guard isSupportedHost else { return false }
        return BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { await run(task: refreshTask) }
        }
    }

    static func schedule(after interval: TimeInterval = 3600, enabled: Bool = true) {
        guard isSupportedHost else { return }
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
        let startedAt = Date()
        var reportID: String?
        var executionStatus: RefreshBatchStatus = .running
        var executionErrors: [String: String] = [:]
        defer {
            RefreshExecutionLog.record(RefreshExecutionRecord(
                trigger: .background,
                startedAt: startedAt,
                finishedAt: Date(),
                status: executionStatus,
                reportID: reportID,
                errorMessages: executionErrors
            ))
        }
        do {
            guard settings.scheduleEnabled else {
                executionStatus = .completed
                task.setTaskCompleted(success: true)
                return
            }
            let preset = TimelineCatalog.preset(for: settings.schedulePreset)
            let calendar = Calendar.trendRadar(timeZoneIdentifier: settings.timezone)
            let match = preset.match(at: Date(), calendar: calendar)
            let timelineAction = TimelineExecutionStore().claim(presetID: preset.id, periodID: match.periodID, action: match.action, calendar: calendar)
            guard timelineAction.collect else {
                executionStatus = .completed
                schedule(after: settings.refreshInterval * 60, enabled: settings.scheduleEnabled)
                task.setTaskCompleted(success: true)
                return
            }
            let feeds = settings.customFeeds.compactMap(\.rssFeed).filter { feed in
                settings.rssEnabled && settings.customFeeds.first(where: { $0.id == feed.id })?.isEnabled == true
            }
            let crawler = NewsCrawler()
            var feedResults: [(String, [NewsItem], String?)] = []
            for feed in feeds {
                do {
                    feedResults.append((feed.name, try await crawler.fetch(feed: feed), nil))
                } catch {
                    feedResults.append((feed.name, [], error.localizedDescription))
                }
            }
            let failedFeeds = feedResults.filter { $0.1.isEmpty }
            executionErrors.merge(
                failedFeeds.reduce(into: [String: String]()) { $0[$1.0] = $1.2 ?? "RSS 源未返回内容" },
                uniquingKeysWith: { current, _ in current }
            )
            let successfulFeedResults = feedResults.filter { !$0.1.isEmpty }
            guard !successfulFeedResults.isEmpty else {
                throw NSError(domain: "TrendRadar.Network", code: -1, userInfo: [NSLocalizedDescriptionKey: executionErrors.values.sorted().joined(separator: "；")])
            }
            var freshItems = successfulFeedResults.flatMap(\.1)
            if !failedFeeds.isEmpty { executionStatus = .partial }
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
                try await localStore.save(report)
                reportID = report.id.uuidString
                let delivery = await ReportDeliveryService().deliver(report: report, settings: settings)
                if let message = delivery.failureMessage {
                    executionErrors["notification"] = message
                    executionStatus = .partial
                }
            }
            if executionStatus != .partial {
                executionStatus = timelineAction.push ? .completed : .partial
            }
            let newCount = freshItems.filter { !oldIDs.contains($0.id) }.count
            if settings.notification.enabled && settings.notification.localAlerts {
                if reportID != nil && timelineAction.push {
                    await notifyReport(soundEnabled: settings.notification.soundEnabled)
                } else if newCount > 0 && timelineAction.push {
                    await notify(newCount: newCount, soundEnabled: settings.notification.soundEnabled)
                }
            }
            schedule(after: settings.refreshInterval * 60, enabled: settings.scheduleEnabled)
            task.setTaskCompleted(success: true)
        } catch {
            executionStatus = error is CancellationError ? .cancelled : .failed
            executionErrors["background"] = error.localizedDescription
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
        let baseURL = AppSettings.effectivePlatformAPIURL(settings.platformAPIURL)
        let service = NewsNowService()
        var results: [(PlatformSource, [HotNewsItem])] = []
        for source in enabledSources {
            do {
                results.append((source, try await service.fetch(sourceID: source.id, sourceName: source.name, expectedDomain: source.expectedDomain, baseURL: baseURL)))
            } catch {
                results.append((source, []))
            }
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

    private static func notifyReport(soundEnabled: Bool) async {
        let content = UNMutableNotificationContent()
        content.title = "TrendRadar"
        content.body = "新的情报报告已生成，可在报告中心查看"
        content.sound = soundEnabled ? .default : nil
        let request = UNNotificationRequest(identifier: "report-generated", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
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
