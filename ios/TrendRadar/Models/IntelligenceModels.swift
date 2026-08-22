import Foundation

enum IntelligenceSourceType: String, Codable, Sendable {
    case hotlist
    case rss
}

struct IntelligenceItem: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let sourceType: IntelligenceSourceType
    let sourceID: String
    let sourceName: String
    let title: String
    let url: URL?
    let publishedAt: Date?
    let summary: String?
    let author: String?
    let topicKey: String
    var rank: Int?
    var previousRank: Int?
    var collectedAt: Date
    var isRead: Bool
    var isFavorite: Bool

    init(
        id: String,
        sourceType: IntelligenceSourceType,
        sourceID: String,
        sourceName: String,
        title: String,
        url: URL? = nil,
        publishedAt: Date? = nil,
        summary: String? = nil,
        author: String? = nil,
        topicKey: String,
        rank: Int? = nil,
        previousRank: Int? = nil,
        collectedAt: Date = Date(),
        isRead: Bool = false,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.sourceType = sourceType
        self.sourceID = sourceID
        self.sourceName = sourceName
        self.title = title
        self.url = url
        self.publishedAt = publishedAt
        self.summary = summary
        self.author = author
        self.topicKey = topicKey
        self.rank = rank
        self.previousRank = previousRank
        self.collectedAt = collectedAt
        self.isRead = isRead
        self.isFavorite = isFavorite
    }
}

struct IntelligenceTopic: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let topicKey: String
    let title: String
    let items: [IntelligenceItem]
    let collectedAt: Date

    var platformNames: [String] {
        Array(Set(items.map(\.sourceName))).sorted()
    }

    var platformCount: Int {
        platformNames.count
    }

    var bestRank: Int? {
        items.compactMap(\.rank).min()
    }
}

enum RefreshBatchTrigger: String, Codable, Sendable {
    case manual
    case foreground
    case background
    case scheduled
}

enum RefreshBatchStatus: String, Codable, Sendable {
    case running
    case completed
    case partial
    case failed
    case cancelled
}

struct RefreshBatch: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let trigger: RefreshBatchTrigger
    let startedAt: Date
    var finishedAt: Date?
    var status: RefreshBatchStatus
    var successfulSourceIDs: [String]
    var failedSourceIDs: [String]
    var errorMessages: [String: String]

    init(
        id: String = UUID().uuidString,
        trigger: RefreshBatchTrigger,
        startedAt: Date = Date(),
        finishedAt: Date? = nil,
        status: RefreshBatchStatus = .running,
        successfulSourceIDs: [String] = [],
        failedSourceIDs: [String] = [],
        errorMessages: [String: String] = [:]
    ) {
        self.id = id
        self.trigger = trigger
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.status = status
        self.successfulSourceIDs = successfulSourceIDs
        self.failedSourceIDs = failedSourceIDs
        self.errorMessages = errorMessages
    }
}

enum SourceDataStatus: String, Codable, Sendable {
    case fresh
    case cached
    case unavailable
}

struct SourceDataCompleteness: Codable, Hashable, Identifiable, Sendable {
    let sourceID: String
    let sourceName: String
    let status: SourceDataStatus
    let itemCount: Int
    let collectedAt: Date?
    let errorMessage: String?

    var id: String { sourceID }

    var hasUsableData: Bool {
        itemCount > 0 && status != .unavailable
    }
}
