import Foundation
import Combine

@MainActor
final class HotNewsStore: ObservableObject {
    @Published private(set) var items: [HotNewsItem] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastUpdated: Date?
    @Published var errorMessage: String?
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

    func trend(for topicKey: String) async -> [TrendPoint] {
        let records = await localStore.loadHotNewsTrend(for: topicKey)
        return records.map { TrendPoint(date: $0.date, rank: $0.rank) }
    }

    func load() async {
        items = await localStore.loadHotNews()
        lastUpdated = await localStore.loadHotNewsLastUpdated()
    }

    func refresh(settings: AppSettings, latest: Bool = false) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        errorMessage = nil
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
            let fetched = await withTaskGroup(of: [HotNewsItem].self) { group in
                for source in enabledSources {
                    group.addTask {
                        do {
                            return try await service.fetch(sourceID: source.id, sourceName: source.name, baseURL: baseURL, latest: latest)
                        } catch {
                            return []
                        }
                    }
                }
                return await group.reduce(into: []) { $0.append(contentsOf: $1) }
            }
            guard !fetched.isEmpty else { throw URLError(.badServerResponse) }
            let oldByID = items.reduce(into: [String: HotNewsItem]()) { $0[$1.id] = $1 }
            items = fetched.map { item in
                var updated = item
                updated.previousRank = oldByID[item.id]?.rank
                updated.isRead = oldByID[item.id]?.isRead ?? false
                updated.isFavorite = oldByID[item.id]?.isFavorite ?? false
                return updated
            }.sorted { $0.rank < $1.rank }
            try await localStore.saveHotNews(items)
            lastUpdated = Date()
        } catch {
            errorMessage = "热榜刷新失败：\(error.localizedDescription)"
            if items.isEmpty { await load() }
        }
    }
}
