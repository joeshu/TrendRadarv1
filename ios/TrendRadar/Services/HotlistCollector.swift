import Foundation

struct CollectorConfiguration: Sendable {
    let baseURL: String
    let latest: Bool
    let batchSize: Int
    let timeout: TimeInterval

    init(baseURL: String, latest: Bool = false, batchSize: Int = 3, timeout: TimeInterval = 20) {
        self.baseURL = baseURL
        self.latest = latest
        self.batchSize = max(1, batchSize)
        self.timeout = timeout
    }
}

struct CollectionResult<Output: Sendable>: Sendable {
    let values: Output
    let batch: RefreshBatch
    let completeness: [SourceDataCompleteness]
}

struct HotlistCollectionOutput: Sendable {
    let items: [HotNewsItem]
    let intelligenceItems: [IntelligenceItem]
    let topics: [IntelligenceTopic]
}

struct HotlistCollector: Sendable {
    private let service: NewsNowService
    private let deduplicator = TopicDeduplicator()

    init(service: NewsNowService = NewsNowService()) {
        self.service = service
    }

    func collect(sources: [PlatformSource], configuration: CollectorConfiguration, trigger: RefreshBatchTrigger = .manual) async -> CollectionResult<HotlistCollectionOutput> {
        let startedAt = Date()
        var results: [(PlatformSource, [HotNewsItem], String?)] = []
        for batch in sources.chunked(into: configuration.batchSize) {
            // Keep collection serial for compatibility with sideload hosts whose
            // Swift concurrency task-group completion can abort the process.
            for source in batch {
                do {
                    let items = try await service.fetch(
                        sourceID: source.id,
                        sourceName: source.name,
                        expectedDomain: source.expectedDomain,
                        baseURL: configuration.baseURL,
                        latest: configuration.latest,
                        timeout: configuration.timeout
                    )
                    results.append((source, items, nil))
                } catch {
                    results.append((source, [], error.localizedDescription))
                }
            }
        }

        let successful = results.filter { !$0.1.isEmpty }
        let failed = results.filter { $0.1.isEmpty }
        let status: RefreshBatchStatus
        if successful.isEmpty {
            status = .failed
        } else if failed.isEmpty {
            status = .completed
        } else {
            status = .partial
        }
        let batch = RefreshBatch(
            trigger: trigger,
            startedAt: startedAt,
            finishedAt: Date(),
            status: status,
            successfulSourceIDs: successful.map { $0.0.id }.sorted(),
            failedSourceIDs: failed.map { $0.0.id }.sorted(),
            errorMessages: failed.reduce(into: [:]) { result, value in
                result[value.0.id] = value.2 ?? "平台未返回内容"
            }
        )
        let items = successful.flatMap { $0.1 }
        let collectedAt = batch.finishedAt ?? Date()
        let intelligenceItems = items.map { item in
            IntelligenceItem(
                id: item.id,
                sourceType: .hotlist,
                sourceID: item.platformID,
                sourceName: item.platformName,
                title: item.title,
                url: item.url,
                publishedAt: item.publishedAt,
                summary: item.extraInfo,
                topicKey: item.topicKey,
                rank: item.rank,
                previousRank: item.previousRank,
                collectedAt: collectedAt,
                isRead: item.isRead,
                isFavorite: item.isFavorite
            )
        }
        let topics = deduplicator.topics(from: intelligenceItems)
        let completeness = results.map { source, values, error in
            SourceDataCompleteness(
                sourceID: source.id,
                sourceName: source.name,
                status: values.isEmpty ? .unavailable : .fresh,
                itemCount: values.count,
                collectedAt: values.isEmpty ? nil : collectedAt,
                errorMessage: error
            )
        }
        return CollectionResult(
            values: HotlistCollectionOutput(items: items, intelligenceItems: intelligenceItems, topics: topics),
            batch: batch,
            completeness: completeness
        )
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { start in
            Array(self[start..<Swift.min(start + size, count)])
        }
    }
}
