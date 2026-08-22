import Foundation
import Combine

@MainActor
final class HotNewsStore: ObservableObject {
    @Published private(set) var items: [HotNewsItem] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastUpdated: Date?
    @Published var errorMessage: String?
    @Published private(set) var sourceFailures: [String] = []
    @Published private(set) var sourceFailureDetails: [String: String] = [:]
    @Published var selectedPlatformID: String?
    @Published private(set) var blockedTopicKeys: Set<String> = []

    struct TrendPoint: Identifiable, Sendable {
        let date: Date
        let rank: Int
        var id: Date { date }
    }

    private let localStore = LocalStore.shared
    private let collector = HotlistCollector()
    private let deduplicator = TopicDeduplicator()

    var filteredItems: [HotNewsItem] {
        guard let selectedPlatformID else { return items }
        return items.filter { $0.platformID == selectedPlatformID }
    }

    var topics: [HotNewsTopic] {
        Dictionary(grouping: filteredItems.filter { !blockedTopicKeys.contains($0.topicKey) }, by: \.topicKey)
            .map { key, values in
                HotNewsTopic(
                    id: key,
                    title: values.min { left, right in
                        if left.rank != right.rank { return left.rank < right.rank }
                        return left.title.localizedCompare(right.title) == .orderedAscending
                    }?.title ?? "",
                    items: values.sorted { left, right in
                        if left.rank != right.rank { return left.rank < right.rank }
                        return left.title.localizedCompare(right.title) == .orderedAscending
                    }
                )
            }
            .sorted { left, right in
                if left.bestRank != right.bestRank { return left.bestRank < right.bestRank }
                return left.title.localizedCompare(right.title) == .orderedAscending
            }
    }

    var anomalies: [HotNewsAnomaly] {
        topics.compactMap { topic in
            let rankedItems = topic.items.compactMap { item -> (item: HotNewsItem, change: Int)? in
                guard let previousRank = item.previousRank else { return nil }
                return (item, previousRank - item.rank)
            }
            guard let strongest = rankedItems.max(by: { abs($0.change) < abs($1.change) }), abs(strongest.change) >= 3 else { return nil }
            return HotNewsAnomaly(topicKey: topic.id, title: topic.title, rank: strongest.item.rank, previousRank: strongest.item.previousRank, change: strongest.change, platforms: topic.platforms)
        }
        .sorted { abs($0.change) > abs($1.change) }
    }

    func trend(for topicKey: String) async -> [TrendPoint] {
        let records = await localStore.loadHotNewsTrend(for: topicKey)
        return records.map { TrendPoint(date: $0.date, rank: $0.rank) }
    }

    func load() async {
        blockedTopicKeys = Set(UserDefaults.standard.stringArray(forKey: "trendradar.blockedTopics") ?? [])
        items = await localStore.loadHotNews()
        lastUpdated = await localStore.loadHotNewsLastUpdated()
    }

    func toggleFavorite(for topic: HotNewsTopic) async {
        let topicIDs = Set(topic.items.map(\.id))
        for index in items.indices where topicIDs.contains(items[index].id) {
            items[index].isFavorite.toggle()
        }
        try? await localStore.saveHotNews(items)
    }

    func block(topic: HotNewsTopic) {
        blockedTopicKeys.insert(topic.id)
        UserDefaults.standard.set(Array(blockedTopicKeys).sorted(), forKey: "trendradar.blockedTopics")
    }

    func clearCache() async throws {
        try await localStore.clearAll()
        items = []
        lastUpdated = nil
        blockedTopicKeys = []
        UserDefaults.standard.removeObject(forKey: "trendradar.blockedTopics")
    }

    func refresh(settings: AppSettings, latest: Bool = false, showError: Bool = true) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        errorMessage = nil
        sourceFailures = []
        sourceFailureDetails = [:]
        defer { isRefreshing = false }
        let baseURL = AppSettings.effectivePlatformAPIURL(settings.platformAPIURL)
        do {
            guard settings.platformsEnabled else {
                errorMessage = "热榜平台功能已关闭"
                return
            }
            let enabledSources = settings.platformSources.filter(\.isEnabled)
            guard !enabledSources.isEmpty else {
                errorMessage = "请先在设置中启用至少一个热榜平台"
                return
            }
            let result = await collector.collect(
                sources: enabledSources,
                configuration: CollectorConfiguration(baseURL: baseURL, latest: latest),
                trigger: latest ? .manual : .foreground
            )
            let fetched = result.values.items
            sourceFailures = result.batch.failedSourceIDs.compactMap { id in
                enabledSources.first(where: { $0.id == id })?.name
            }.sorted()
            sourceFailureDetails = result.batch.errorMessages.reduce(into: [:]) { details, entry in
                if let source = enabledSources.first(where: { $0.id == entry.key }) {
                    details[source.name] = entry.value
                }
            }
            guard !fetched.isEmpty else {
                let details = sourceFailureDetails.values.sorted().joined(separator: "；")
                throw NSError(domain: "TrendRadar.HotNews", code: -1, userInfo: [NSLocalizedDescriptionKey: details.isEmpty ? "所有热榜平台均未返回内容" : details])
            }
            let oldByID = items.reduce(into: [String: HotNewsItem]()) { $0[$1.id] = $1 }
            let refreshed = fetched.map { item in
                var updated = item
                updated.previousRank = oldByID[item.id]?.rank
                updated.firstSeenAt = oldByID[item.id]?.firstSeenAt ?? Date()
                updated.isRead = oldByID[item.id]?.isRead ?? false
                updated.isFavorite = oldByID[item.id]?.isFavorite ?? false
                return updated
            }
            let successfulPlatformIDs = Set(result.batch.successfulSourceIDs)
            let staleItems = items.filter { item in
                !successfulPlatformIDs.contains(item.platformID) && sourceFailures.contains(item.platformName)
            }
            items = (refreshed + staleItems).sorted { $0.rank < $1.rank }
            try await localStore.saveHotNews(items, replacingPlatformIDs: successfulPlatformIDs)
            try await localStore.saveIntelligenceSnapshot(
                items: result.values.intelligenceItems,
                topics: result.values.topics,
                batch: result.batch,
                replacingSourceIDs: successfulPlatformIDs
            )
            lastUpdated = Date()
        } catch {
            let suffix = sourceFailures.isEmpty ? "" : "失败平台：\(sourceFailures.joined(separator: "、"))。"
            let details = sourceFailures.compactMap { name in
                sourceFailureDetails[name].map { "\(name)：\($0)" }
            }.joined(separator: "；")
            let reason = details.isEmpty ? error.localizedDescription : details
            if showError {
                errorMessage = "热榜刷新失败：\(reason)\(suffix)"
            }
            if items.isEmpty { await load() }
        }
    }
}
