import Foundation

struct RankSnapshot: Codable, Hashable, Identifiable, Sendable {
    let sourceID: String
    let sourceName: String
    let rank: Int
    let capturedAt: Date

    var id: String { "\(sourceID):\(capturedAt.timeIntervalSince1970):\(rank)" }
}

enum TrendState: String, Codable, CaseIterable, Sendable {
    case new
    case rising
    case falling
    case stable
    case sustained
}

enum RadarFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case rising
    case new
    case sustained
    case following

    var id: String { rawValue }

    func includes(_ topic: HotNewsTopic, now: Date = Date()) -> Bool {
        switch self {
        case .all: return true
        case .rising: return topic.strongestTrend == .up
        case .new: return topic.strongestTrend == .new
        case .sustained:
            guard let firstSeenAt = topic.firstSeenAt else { return false }
            return now.timeIntervalSince(firstSeenAt) >= 6 * 60 * 60
        case .following: return topic.items.contains(where: \.isFavorite)
        }
    }
}

struct TrendTopic: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let normalizedTitle: String
    let title: String
    let items: [IntelligenceItem]
    let firstSeenAt: Date
    let lastSeenAt: Date
    let rankSnapshots: [RankSnapshot]
    let state: TrendState

    var platformCount: Int { Set(items.filter { $0.sourceType == .hotlist }.map(\.sourceID)).count }
    var sourceCount: Int { Set(items.map(\.sourceID)).count }
    var bestRank: Int? { rankSnapshots.map(\.rank).min() ?? items.compactMap(\.rank).min() }

    init(
        id: String,
        normalizedTitle: String,
        title: String,
        items: [IntelligenceItem],
        firstSeenAt: Date,
        lastSeenAt: Date,
        rankSnapshots: [RankSnapshot] = [],
        state: TrendState? = nil
    ) {
        self.id = id
        self.normalizedTitle = normalizedTitle
        self.title = title
        self.items = items
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.rankSnapshots = rankSnapshots.sorted { $0.capturedAt < $1.capturedAt }
        self.state = state ?? TrendStateClassifier.classify(
            snapshots: self.rankSnapshots,
            firstSeenAt: firstSeenAt,
            lastSeenAt: lastSeenAt
        )
    }
}

enum TrendStateClassifier {
    static func classify(
        snapshots: [RankSnapshot],
        firstSeenAt: Date,
        lastSeenAt: Date,
        sustainedAfter: TimeInterval = 6 * 60 * 60
    ) -> TrendState {
        let ordered = snapshots.sorted { $0.capturedAt < $1.capturedAt }
        guard ordered.count >= 2 else { return .new }
        let duration = max(0, lastSeenAt.timeIntervalSince(firstSeenAt))
        let change = ordered.first!.rank - ordered.last!.rank
        if change > 0 { return .rising }
        if change < 0 { return .falling }
        return duration >= sustainedAfter ? .sustained : .stable
    }
}

struct SourceHealth: Codable, Hashable, Identifiable, Sendable {
    let sourceID: String
    var sourceName: String
    var lastSuccessAt: Date?
    var lastError: String?
    var consecutiveFailures: Int
    var cacheAvailable: Bool

    var id: String { sourceID }

    init(
        sourceID: String,
        sourceName: String,
        lastSuccessAt: Date? = nil,
        lastError: String? = nil,
        consecutiveFailures: Int = 0,
        cacheAvailable: Bool = false
    ) {
        self.sourceID = sourceID
        self.sourceName = sourceName
        self.lastSuccessAt = lastSuccessAt
        self.lastError = lastError
        self.consecutiveFailures = consecutiveFailures
        self.cacheAvailable = cacheAvailable
    }

    mutating func recordSuccess(at date: Date, cacheAvailable: Bool) {
        lastSuccessAt = date
        lastError = nil
        consecutiveFailures = 0
        self.cacheAvailable = cacheAvailable
    }

    mutating func recordFailure(_ message: String, cacheAvailable: Bool) {
        lastError = message
        consecutiveFailures += 1
        self.cacheAvailable = cacheAvailable
    }
}
