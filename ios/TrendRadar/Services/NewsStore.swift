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
    @Published private(set) var sourceFailureDetails: [String: String] = [:]
    @Published private(set) var feedHealth: [String: FeedHealth] = [:]

    private let localStore = LocalStore.shared
    private let crawler = NewsCrawler()
    private let aiService = AIService()
    var settings: AppSettings = AppSettings()

    var feeds: [RSSFeed] {
        settings.customFeeds.compactMap(\.rssFeed)
    }

    func load() async {
        loadFeedHealth()
        items = await localStore.load()
        lastUpdated = items.compactMap(\.publishedAt).max()
    }

    func clearCache() async throws {
        try await localStore.clearAll()
        items = []
        lastUpdated = nil
        feedHealth = [:]
        UserDefaults.standard.removeObject(forKey: "trendradar.feedHealth")
    }

    func refresh(showError: Bool = true, autoReport: Bool = true) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        let startedAt = Date()
        var executionStatus: RefreshBatchStatus = .running
        var executionErrors: [String: String] = [:]
        defer {
            RefreshExecutionLog.record(RefreshExecutionRecord(
                trigger: .foreground,
                startedAt: startedAt,
                finishedAt: Date(),
                status: executionStatus,
                errorMessages: executionErrors
            ))
            isRefreshing = false
        }
        errorMessage = nil
        sourceFailures = []
        sourceFailureDetails = [:]

        do {
            guard settings.rssEnabled else {
                executionStatus = .completed
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
            let results = await withTaskGroup(of: (String, [NewsItem], String?).self) { group in
                for feed in enabledFeeds {
                    group.addTask {
                        do {
                            return (feed.name, try await crawler.fetch(feed: feed), nil)
                        } catch {
                            return (feed.name, [], error.localizedDescription)
                        }
                    }
                }
                return await group.reduce(into: [(String, [NewsItem], String?) ]()) { result, value in
                    result.append(value)
                }
            }
            sourceFailures = results.filter { $0.1.isEmpty }.map(\.0).sorted()
            sourceFailureDetails = results.reduce(into: [:]) { details, result in
                if let detail = result.2 {
                    details[result.0] = detail
                }
            }
            executionErrors = sourceFailureDetails
            executionStatus = sourceFailures.isEmpty ? .completed : .partial
            updateFeedHealth(enabledFeeds: enabledFeeds, failedNames: sourceFailures, details: sourceFailureDetails)
            let successfulResults = results.filter { !$0.1.isEmpty }
            guard !successfulResults.isEmpty else {
                if !items.isEmpty {
                    executionStatus = .failed
                    if showError {
                        errorMessage = "刷新失败，已保留本地缓存：\(sourceFailures.joined(separator: "、"))"
                    }
                    return
                }
                let details = sourceFailureDetails.values.sorted().joined(separator: "；")
                throw NSError(domain: "TrendRadar.Network", code: -1, userInfo: [NSLocalizedDescriptionKey: details.isEmpty ? "所有 RSS 源均未返回内容" : details])
            }
            let oldByID = items.reduce(into: [String: NewsItem]()) { $0[$1.id] = $1 }
            let fetchedItems = successfulResults.flatMap(\.1)
            let uniqueResults = fetchedItems.reduce(into: [String: NewsItem]()) { $0[$1.id] = $1 }.values
            let filterEngine = FilterEngine(settings: settings)
            var filteredResults = uniqueResults.filter { filterEngine.includes($0) }
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
                let details = sourceFailures.compactMap { name in
                    sourceFailureDetails[name].map { "\(name)：\($0)" }
                }.joined(separator: "；")
                if showError {
                    errorMessage = details.isEmpty ? "部分 RSS 源刷新失败：\(sourceFailures.joined(separator: "、"))" : "部分 RSS 源刷新失败：\(details)"
                }
            }
            let preset = TimelineCatalog.preset(for: settings.schedulePreset)
            let calendar = Calendar.trendRadar(timeZoneIdentifier: settings.timezone)
            let match = preset.match(at: Date(), calendar: calendar)
            let timelineAction = autoReport
                ? TimelineExecutionStore().claim(presetID: preset.id, periodID: match.periodID, action: match.action, calendar: calendar)
                : TimelineAction.passive
            if autoReport, settings.scheduleEnabled, timelineAction.push {
                await generateReport(trigger: .foregroundRefresh, type: timelineAction.reportMode)
            }
        } catch {
            let details = sourceFailures.compactMap { name in
                sourceFailureDetails[name].map { "\(name)：\($0)" }
            }.joined(separator: "；")
            if showError {
                errorMessage = details.isEmpty ? "刷新失败：\(error.localizedDescription)" : "RSS 刷新失败：\(details)"
            }
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

    func markAllRead() async {
        items = items.map { item in
            var updated = item
            updated.isRead = true
            return updated
        }
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
            let standaloneContent = aiService.standaloneContent(hotlistItems: hotlistItems, rssItems: items, settings: settings)
            report.aiAnalysis = await aiService.reportAnalysis(hotlistItems: hotlistItems, rssItems: items, settings: settings, reportType: type.displayName, standaloneContent: standaloneContent)
            report.aiAnalysis?.citations = report.sections.flatMap(\.items).compactMap { item in
                InsightCitation(itemID: item.id, title: item.title, source: item.source, url: item.url)
            }
        }
        do {
            try await localStore.save(report)
            let webhookDelivered = await GenericWebhookService().send(report: report, settings: settings)
            if !webhookDelivered, let delivery = GenericWebhookService.records().first(where: { $0.reportID == report.id.uuidString }) {
                errorMessage = "自动报告已保存，但 Webhook 投递失败：\(delivery.message)"
            }
        } catch {
            errorMessage = "自动报告保存失败：\(error.localizedDescription)"
        }
    }

    private func matchesConfiguredFilters(_ item: NewsItem) -> Bool {
        guard FilterEngine(settings: settings).includes(item) else { return false }
        guard settings.rssFreshnessEnabled, let publishedAt = item.publishedAt else { return true }
        let feedAge = settings.customFeeds.first { $0.name == item.source }?.maxAgeDays ?? 0
        let maxAgeDays = feedAge > 0 ? feedAge : settings.rssMaxAgeDays
        guard maxAgeDays > 0 else { return true }
        return publishedAt >= Date(timeIntervalSinceNow: -Double(maxAgeDays) * 86_400)
    }

    private func loadFeedHealth() {
        guard let data = UserDefaults.standard.data(forKey: "trendradar.feedHealth"),
              let health = try? JSONDecoder().decode([String: FeedHealth].self, from: data) else { return }
        feedHealth = health
    }

    private func updateFeedHealth(enabledFeeds: [RSSFeed], failedNames: [String], details: [String: String]) {
        for feed in enabledFeeds {
            var status = feedHealth[feed.id] ?? FeedHealth(sourceID: feed.id, consecutiveFailures: 0, lastSuccessAt: nil, lastFailureAt: nil, lastError: nil)
            if failedNames.contains(feed.name) {
                status.consecutiveFailures += 1
                status.lastFailureAt = Date()
                status.lastError = details[feed.name]
            } else {
                status.consecutiveFailures = 0
                status.lastSuccessAt = Date()
                status.lastError = nil
            }
            feedHealth[feed.id] = status
        }
        if let data = try? JSONEncoder().encode(feedHealth) {
            UserDefaults.standard.set(data, forKey: "trendradar.feedHealth")
        }
    }
}
