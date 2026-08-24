import Foundation
import Combine

@MainActor
final class ArchiveStore: ObservableObject {
    @Published private(set) var items: [ArchiveResource] = []
    @Published var searchText = ""
    @Published var selectedKind: ArchiveResourceKind?
    @Published var errorMessage: String?

    private let localStore = LocalStore.shared

    var filteredItems: [ArchiveResource] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return items.filter { item in
            (selectedKind == nil || item.kind == selectedKind) &&
            (query.isEmpty || item.searchableText.localizedCaseInsensitiveContains(query))
        }
    }

    func synchronize(news: [NewsItem], topics: [HotNewsTopic], reports: [ReportSummary]) async {
        let resources = news.filter { $0.isFavorite || $0.inboxState == .archived }.map { ArchiveResource(news: $0) }
            + topics.filter { $0.items.contains(where: \.isFavorite) }.map { ArchiveResource(topic: $0) }
            + reports.filter(\.isFavorite).map { ArchiveResource(report: $0) }
        do {
            for resource in resources { try await localStore.saveArchive(resource) }
            items = await localStore.loadArchive()
        } catch {
            errorMessage = "资料库同步失败：\(error.localizedDescription)"
            items = await localStore.loadArchive()
        }
    }

    func delete(_ item: ArchiveResource) async {
        do {
            try await localStore.deleteArchive(resourceID: item.resourceID, kind: item.kind)
            items = await localStore.loadArchive()
        } catch {
            errorMessage = "移出资料库失败：\(error.localizedDescription)"
        }
    }
}
