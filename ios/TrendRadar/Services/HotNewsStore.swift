import Foundation
import Combine

@MainActor
final class HotNewsStore: ObservableObject {
    @Published private(set) var items: [HotNewsItem] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastUpdated: Date?
    @Published var errorMessage: String?
    @Published private(set) var sourceFailures: [String] = []
    @Published var selectedPlatformID: String?

    struct TrendPoint: Identifiable, Sendable {
        let date: Date
        let rank: Int
        var id: Date { date }
    }

    private let localStore = LocalStore()
    private let service = NewsNowService()

    var filteredItems: [HotNewsItem] {
        guard let selectedPlatformID else { return items }
        return items.filter { $0.platformID == selectedPlatformID }
    }

    var topics: [HotNewsTopic] {
        Dictionary(grouping: filteredItems, by: \.topicKey)
            .map { HotNewsTopic(id: $0.key, title: $0.value.min { $0.rank < $1.rank }?.title ?? "", items: $0.value.sorted { $0.rank < $1.rank }) }
            .sorted { $0.bestRank < $1.bestRank }
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
        items = await localStore.loadHotNews()
        lastUpdated = await localStore.loadHotNewsLastUpdated()
    }

    func clearCache() async throws {
        try await localStore.clearAll()
        items = []
        lastUpdated = nil
    }

    func refresh(settings: AppSettings, latest: Bool = false) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        errorMessage = nil
        sourceFailures = []
        defer { isRefreshing = false }
        let baseURL = settings.platformAPIURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "https://newsnow.busiyi.world/api" : settings.platformAPIURL
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
            let service = self.service
            let results = await withTaskGroup(of: (String, [HotNewsItem]).self) { group in
                for source in enabledSources {
                    group.addTask {
                        do {
                            return (source.name, try await service.fetch(sourceID: source.id, sourceName: source.name, expectedDomain: source.expectedDomain, baseURL: baseURL, latest: latest))
                        } catch {
                            return (source.name, [])
                        }
                    }
                }
                return await group.reduce(into: [(String, [HotNewsItem])]()) { $0.append($1) }
            }
            let fetched = results.flatMap(\.1)
            sourceFailures = results.filter { $0.1.isEmpty }.map(\.0).sorted()
            guard !fetched.isEmpty else { throw URLError(.badServerResponse) }
            let oldByID = items.reduce(into: [String: HotNewsItem]()) { $0[$1.id] = $1 }
            let refreshed = fetched.map { item in
                var updated = item
                updated.previousRank = oldByID[item.id]?.rank
                updated.isRead = oldByID[item.id]?.isRead ?? false
                updated.isFavorite = oldByID[item.id]?.isFavorite ?? false
                return updated
            }
            let successfulSourceNames = Set(results.filter { !$0.1.isEmpty }.map(\.0))
            let successfulPlatformIDs = Set(enabledSources.filter { successfulSourceNames.contains($0.name) }.map(\.id))
            let staleItems = items.filter { item in
                !successfulPlatformIDs.contains(item.platformID) && sourceFailures.contains(item.platformName)
            }
            items = (refreshed + staleItems).sorted { $0.rank < $1.rank }
            try await localStore.saveHotNews(items, replacingPlatformIDs: successfulPlatformIDs)
            lastUpdated = Date()
        } catch {
            let suffix = sourceFailures.isEmpty ? "" : "失败平台：\(sourceFailures.joined(separator: "、"))。"
            errorMessage = "热榜刷新失败：\(error.localizedDescription)\(suffix)"
            if items.isEmpty { await load() }
        }
    }
}
