import Foundation
import UserNotifications

actor RefreshPipelineExecutor {
    static let shared = RefreshPipelineExecutor()

    private struct CollectionSnapshot {
        let freshItems: [NewsItem]
        let hotNews: [HotNewsItem]
        let oldItems: [NewsItem]
        let enabledSourceNames: Set<String>
        let sourceErrors: [String: String]
    }

    private struct PersistedSnapshot {
        let items: [NewsItem]
        let hotNews: [HotNewsItem]
        let newItemCount: Int
        let sourceErrors: [String: String]
    }

    private var running = false

    func execute(context: PipelineExecutionContext) async throws -> RefreshPipelineExecutionResult {
        guard !running else { return RefreshPipelineExecutionResult(status: .skipped, context: context) }
        running = true
        defer { running = false }

        var stages: [PipelineStageResult] = []
        var reportID: String?
        var deliveryStatus: DeliveryStatus = .notAttempted
        do {
            let settings = loadSettings()
            let action = timelineAction(settings: settings, trigger: context.trigger)
            guard context.trigger != .background || settings.scheduleEnabled, action.collect else {
                await saveDiagnostics(context, stages, nil, .notAttempted)
                return RefreshPipelineExecutionResult(status: .skipped, context: context)
            }

            let collected = try await runStage("collector", results: &stages) { try await self.collect(settings, context.trigger) }
            try Task.checkCancellation()
            let filtered = try await runStage("filter", results: &stages) { try await self.filter(collected.freshItems, settings) }
            try Task.checkCancellation()
            let persisted = try await runStage("persist", results: &stages) { await self.persist(filtered, collected) }
            try Task.checkCancellation()

            var sourceErrors = persisted.sourceErrors
            if action.push {
                let report = try await runStage("report", results: &stages) {
                    try await self.makeReport(persisted, settings, action, context)
                }
                reportID = report.id.uuidString
                let startedAt = Date()
                let delivery = await ReportDeliveryService().deliver(report: report, settings: settings)
                deliveryStatus = delivery.failureMessage == nil ? .delivered : .failed
                if let message = delivery.failureMessage { sourceErrors["notification"] = message }
                await notify(reportCreated: true, newItemCount: persisted.newItemCount, settings: settings)
                stages.append(PipelineStageResult(name: "delivery", success: delivery.failureMessage == nil, message: delivery.failureMessage, duration: Date().timeIntervalSince(startedAt)))
            }
            await saveDiagnostics(context, stages, reportID, deliveryStatus)
            return RefreshPipelineExecutionResult(
                status: .completed,
                context: context,
                reportCreated: reportID != nil,
                deliveryCompleted: deliveryStatus == .delivered,
                newItemCount: persisted.newItemCount,
                sourceErrors: sourceErrors
            )
        } catch {
            await saveDiagnostics(context, stages, reportID, deliveryStatus)
            throw error
        }
    }

    private func collect(_ settings: AppSettings, _ trigger: RefreshTrigger) async throws -> CollectionSnapshot {
        let localStore = LocalStore.shared
        let oldItems = await localStore.load()
        let oldHotNews = await localStore.loadHotNews()
        let feeds = settings.customFeeds.compactMap(\.rssFeed).filter { feed in
            settings.rssEnabled && settings.customFeeds.first(where: { $0.id == feed.id })?.isEnabled == true
        }
        let crawler = NewsCrawler()
        var freshItems: [NewsItem] = []
        var errors: [String: String] = [:]
        for feed in feeds {
            do { freshItems.append(contentsOf: try await crawler.fetch(feed: feed)) }
            catch { errors[feed.name] = error.localizedDescription }
        }
        if !feeds.isEmpty && freshItems.isEmpty {
            throw PipelineError.collectorFailed(errors.values.sorted().joined(separator: "；"))
        }
        let hotNews = await collectHotNews(settings, oldHotNews, localStore, trigger, &errors)
        return CollectionSnapshot(freshItems: freshItems, hotNews: hotNews, oldItems: oldItems, enabledSourceNames: Set(feeds.map(\.name)), sourceErrors: errors)
    }

    private func collectHotNews(_ settings: AppSettings, _ previous: [HotNewsItem], _ localStore: LocalStore, _ trigger: RefreshTrigger, _ errors: inout [String: String]) async -> [HotNewsItem] {
        guard settings.platformsEnabled else { return [] }
        let sources = settings.platformSources.filter(\.isEnabled)
        guard !sources.isEmpty else { return previous }
        let service = NewsNowService()
        let baseURL = AppSettings.effectivePlatformAPIURL(settings.platformAPIURL)
        var successful: [(PlatformSource, [HotNewsItem])] = []
        for source in sources {
            do {
                let items = try await service.fetch(sourceID: source.id, sourceName: source.name, expectedDomain: source.expectedDomain, baseURL: baseURL)
                if items.isEmpty {
                    errors[source.name] = "热榜源未返回内容"
                    await SourceHealthStore.shared.record(sourceID: source.id, sourceName: source.name, error: "热榜源未返回内容", cacheAvailable: previous.contains { $0.platformID == source.id })
                } else {
                    successful.append((source, items))
                    await SourceHealthStore.shared.record(sourceID: source.id, sourceName: source.name, error: nil, cacheAvailable: true)
                }
            } catch {
                errors[source.name] = error.localizedDescription
                await SourceHealthStore.shared.record(sourceID: source.id, sourceName: source.name, error: error.localizedDescription, cacheAvailable: previous.contains { $0.platformID == source.id })
            }
        }
        guard !successful.isEmpty else { return previous }
        let previousByID = previous.reduce(into: [String: HotNewsItem]()) { $0[$1.id] = $1 }
        let fetched = successful.flatMap(\.1).map { item in
            var updated = item
            updated.previousRank = previousByID[item.id]?.rank
            updated.firstSeenAt = previousByID[item.id]?.firstSeenAt ?? Date()
            updated.isRead = previousByID[item.id]?.isRead ?? false
            updated.isFavorite = previousByID[item.id]?.isFavorite ?? false
            return updated
        }
        let successfulIDs = Set(successful.map { $0.0.id })
        let merged = (fetched + previous.filter { !successfulIDs.contains($0.platformID) }).sorted { $0.rank < $1.rank }
        try? await localStore.saveHotNews(merged, replacingPlatformIDs: successfulIDs)
        let collectedAt = Date()
        let intelligenceItems = merged.map {
            IntelligenceItem(
                id: $0.id,
                sourceType: .hotlist,
                sourceID: $0.platformID,
                sourceName: $0.platformName,
                title: $0.title,
                url: $0.url,
                publishedAt: $0.publishedAt,
                summary: $0.extraInfo,
                topicKey: $0.topicKey,
                rank: $0.rank,
                previousRank: $0.previousRank,
                collectedAt: collectedAt,
                isRead: $0.isRead,
                isFavorite: $0.isFavorite
            )
        }
        let failedIDs = sources.filter { errors[$0.name] != nil }.map(\.id)
        let batch = RefreshBatch(
            trigger: batchTrigger(for: trigger),
            startedAt: collectedAt,
            finishedAt: collectedAt,
            status: failedIDs.isEmpty ? .completed : .partial,
            successfulSourceIDs: Array(successfulIDs).sorted(),
            failedSourceIDs: failedIDs.sorted(),
            errorMessages: Dictionary(uniqueKeysWithValues: sources.compactMap { source in errors[source.name].map { (source.id, $0) } })
        )
        try? await localStore.saveIntelligenceSnapshot(
            items: intelligenceItems,
            topics: TopicDeduplicator().topics(from: intelligenceItems),
            batch: batch,
            replacingSourceIDs: successfulIDs
        )
        return merged
    }

    private func batchTrigger(for trigger: RefreshTrigger) -> RefreshBatchTrigger {
        switch trigger {
        case .manual: return .manual
        case .background: return .background
        default: return .foreground
        }
    }

    private func filter(_ items: [NewsItem], _ settings: AppSettings) async throws -> [NewsItem] {
        try Task.checkCancellation()
        let engine = FilterEngine(settings: settings)
        var result = items.filter { engine.includes($0) }
        if settings.rssFreshnessEnabled {
            result = result.filter { item in
                let customAge = settings.customFeeds.first { $0.name == item.source }?.maxAgeDays ?? 0
                let days = customAge > 0 ? customAge : settings.rssMaxAgeDays
                guard days > 0 else { return true }
                return item.publishedAt.map { $0 >= Date(timeIntervalSinceNow: -Double(days) * 86_400) } ?? true
            }
        }
        if settings.ai.enabled, settings.ai.filterMethod == "ai", !settings.ai.interests.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result = (try? await AIService().filter(result, settings: settings)) ?? result
        }
        return result
    }

    private func persist(_ filtered: [NewsItem], _ collection: CollectionSnapshot) async -> PersistedSnapshot {
        let oldByID = collection.oldItems.reduce(into: [String: NewsItem]()) { $0[$1.id] = $1 }
        let oldIDs = Set(oldByID.keys)
        let refreshed = filtered.reduce(into: [String: NewsItem]()) { result, item in
            var updated = item
            updated.isRead = oldByID[item.id]?.isRead ?? false
            updated.isFavorite = oldByID[item.id]?.isFavorite ?? false
            result[item.id] = updated
        }
        var merged = Array(refreshed.values)
        merged.append(contentsOf: collection.oldItems.filter { collection.enabledSourceNames.contains($0.source) && refreshed[$0.id] == nil })
        await LocalStore.shared.save(merged)
        return PersistedSnapshot(items: merged, hotNews: collection.hotNews, newItemCount: filtered.filter { !oldIDs.contains($0.id) }.count, sourceErrors: collection.sourceErrors)
    }

    private func makeReport(_ snapshot: PersistedSnapshot, _ settings: AppSettings, _ action: TimelineAction, _ context: PipelineExecutionContext) async throws -> ReportDetail {
        let request = ReportGenerationRequest(batchID: "\(context.trigger.rawValue):\(context.requestID.uuidString)", type: action.reportMode, trigger: context.trigger == .manual ? .manual : .backgroundRefresh, generatedAt: Date(), settings: settings)
        var report = ReportGenerationService().generate(request: request, items: snapshot.items, hotlistItems: snapshot.hotNews)
        if action.analyze, settings.ai.enabled, settings.aiAnalysis.enabled {
            let service = AIService()
            let content = service.standaloneContent(hotlistItems: snapshot.hotNews, rssItems: snapshot.items, settings: settings)
            report.aiAnalysis = await service.reportAnalysis(hotlistItems: snapshot.hotNews, rssItems: snapshot.items, settings: settings, reportType: action.reportMode.displayName, standaloneContent: content)
            report.aiAnalysis?.citations = report.sections.flatMap(\.items).compactMap { InsightCitation(itemID: $0.id, title: $0.title, source: $0.source, url: $0.url) }
        }
        try await LocalStore.shared.save(report)
        return report
    }

    private func timelineAction(settings: AppSettings, trigger: RefreshTrigger) -> TimelineAction {
        guard trigger == .background else { return .passive }
        let preset = TimelineCatalog.preset(for: settings.schedulePreset)
        let calendar = Calendar.trendRadar(timeZoneIdentifier: settings.timezone)
        let match = preset.match(at: Date(), calendar: calendar)
        return TimelineExecutionStore().claim(presetID: preset.id, periodID: match.periodID, action: match.action, calendar: calendar)
    }

    private func notify(reportCreated: Bool, newItemCount: Int, settings: AppSettings) async {
        guard settings.notification.enabled, settings.notification.localAlerts, reportCreated || newItemCount > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = "TrendRadar"
        content.body = reportCreated ? "新的情报报告已生成，可在洞察中查看" : "发现 \(newItemCount) 条新热点"
        content.sound = settings.notification.soundEnabled ? .default : nil
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: reportCreated ? "report-generated" : "new-news", content: content, trigger: nil))
    }

    private func loadSettings() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: "trendradar.settings"), let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else { return AppSettings() }
        return settings
    }

    private func runStage<Output>(_ name: String, results: inout [PipelineStageResult], operation: () async throws -> Output) async throws -> Output {
        let startedAt = Date()
        do {
            let output = try await operation()
            results.append(PipelineStageResult(name: name, success: true, message: nil, duration: Date().timeIntervalSince(startedAt)))
            return output
        } catch {
            results.append(PipelineStageResult(name: name, success: false, message: error.localizedDescription, duration: Date().timeIntervalSince(startedAt)))
            throw error
        }
    }

    private func saveDiagnostics(_ context: PipelineExecutionContext, _ stages: [PipelineStageResult], _ reportID: String?, _ deliveryStatus: DeliveryStatus) async {
        await PipelineDiagnosticsStore.shared.save(PipelineExecutionReport(requestID: context.requestID, trigger: context.trigger, startedAt: context.startedAt, finishedAt: Date(), stageResults: stages, reportID: reportID, deliveryStatus: deliveryStatus))
    }
}

struct RefreshPipelineExecutionResult: Sendable {
    enum Status: Sendable { case completed, skipped }
    let status: Status
    let context: PipelineExecutionContext
    let reportCreated: Bool
    let deliveryCompleted: Bool
    let newItemCount: Int
    let sourceErrors: [String: String]

    init(status: Status, context: PipelineExecutionContext, reportCreated: Bool = false, deliveryCompleted: Bool = false, newItemCount: Int = 0, sourceErrors: [String: String] = [:]) {
        self.status = status
        self.context = context
        self.reportCreated = reportCreated
        self.deliveryCompleted = deliveryCompleted
        self.newItemCount = newItemCount
        self.sourceErrors = sourceErrors
    }
}
