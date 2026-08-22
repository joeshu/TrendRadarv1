import Foundation

struct TopicDeduplicator: Sendable {
    func topicKey(for title: String) -> String {
        Self.normalizedKey(for: title)
    }

    func topics(from items: [IntelligenceItem]) -> [IntelligenceTopic] {
        Dictionary(grouping: items, by: { topicKey(for: $0.title) })
            .compactMap { key, groupedItems in
                guard let representative = groupedItems.min(by: Self.rankOrdering) else { return nil }
                return IntelligenceTopic(
                    id: key,
                    topicKey: key,
                    title: representative.title,
                    items: groupedItems.sorted(by: Self.rankOrdering),
                    collectedAt: groupedItems.map(\.collectedAt).max() ?? Date()
                )
            }
            .sorted { ($0.bestRank ?? Int.max) < ($1.bestRank ?? Int.max) }
    }

    private static func rankOrdering(_ left: IntelligenceItem, _ right: IntelligenceItem) -> Bool {
        let leftRank = left.rank ?? Int.max
        let rightRank = right.rank ?? Int.max
        if leftRank != rightRank { return leftRank < rightRank }
        return left.title.localizedCompare(right.title) == .orderedAscending
    }

    private static func normalizedKey(for title: String) -> String {
        let lowered = title.lowercased()
        let scalars = lowered.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        var key = String(String.UnicodeScalarView(scalars))
        for suffix in ["热搜", "热榜", "话题", "讨论", "官方"] where key.hasSuffix(suffix) && key.count > suffix.count {
            key.removeLast(suffix.count)
        }
        return key.isEmpty ? "untitled" : key
    }
}
