import Foundation
import SwiftData

@Model
final class IntelligenceRecord {
    @Attribute(.unique) var id: String
    var sourceType: String
    var sourceID: String
    var sourceName: String
    var title: String
    var urlString: String?
    var publishedAt: Date?
    var summary: String?
    var author: String?
    var topicKey: String
    var rank: Int?
    var previousRank: Int?
    var collectedAt: Date
    var isRead: Bool
    var isFavorite: Bool

    init(item: IntelligenceItem) {
        id = item.id
        sourceType = item.sourceType.rawValue
        sourceID = item.sourceID
        sourceName = item.sourceName
        title = item.title
        urlString = item.url?.absoluteString
        publishedAt = item.publishedAt
        summary = item.summary
        author = item.author
        topicKey = item.topicKey
        rank = item.rank
        previousRank = item.previousRank
        collectedAt = item.collectedAt
        isRead = item.isRead
        isFavorite = item.isFavorite
    }

    func update(with item: IntelligenceItem) {
        sourceType = item.sourceType.rawValue
        sourceID = item.sourceID
        sourceName = item.sourceName
        title = item.title
        urlString = item.url?.absoluteString
        publishedAt = item.publishedAt
        summary = item.summary
        author = item.author
        topicKey = item.topicKey
        rank = item.rank
        previousRank = item.previousRank
        collectedAt = item.collectedAt
        isRead = item.isRead
        isFavorite = item.isFavorite
    }
}

@Model
final class TopicRecord {
    @Attribute(.unique) var id: String
    var topicKey: String
    var title: String
    var platformNames: String
    var collectedAt: Date

    init(topic: IntelligenceTopic) {
        id = topic.id
        topicKey = topic.topicKey
        title = topic.title
        platformNames = topic.platformNames.joined(separator: "\n")
        collectedAt = topic.collectedAt
    }

    func update(with topic: IntelligenceTopic) {
        title = topic.title
        platformNames = topic.platformNames.joined(separator: "\n")
        collectedAt = topic.collectedAt
    }
}

@Model
final class TopicItemLinkRecord {
    @Attribute(.unique) var id: String
    var topicID: String
    var itemID: String
    var batchID: String
    var rank: Int?
    var collectedAt: Date

    init(topicID: String, itemID: String, batchID: String, rank: Int?, collectedAt: Date) {
        id = "\(batchID):\(topicID):\(itemID)"
        self.topicID = topicID
        self.itemID = itemID
        self.batchID = batchID
        self.rank = rank
        self.collectedAt = collectedAt
    }
}

@Model
final class HotlistSnapshotRecord {
    @Attribute(.unique) var id: String
    var batchID: String
    var itemID: String
    var platformID: String
    var topicKey: String
    var rank: Int?
    var capturedAt: Date

    init(item: IntelligenceItem, batchID: String) {
        id = "\(batchID):\(item.id)"
        self.batchID = batchID
        itemID = item.id
        platformID = item.sourceID
        topicKey = item.topicKey
        rank = item.rank
        capturedAt = item.collectedAt
    }
}

@Model
final class RefreshRunRecord {
    @Attribute(.unique) var id: String
    var trigger: String
    var startedAt: Date
    var finishedAt: Date?
    var status: String
    var successfulSourceIDs: String
    var failedSourceIDs: String
    var errorMessagesJSON: Data?

    init(batch: RefreshBatch, encoder: JSONEncoder = .trendRadar) {
        id = batch.id
        trigger = batch.trigger.rawValue
        startedAt = batch.startedAt
        finishedAt = batch.finishedAt
        status = batch.status.rawValue
        successfulSourceIDs = batch.successfulSourceIDs.joined(separator: "\n")
        failedSourceIDs = batch.failedSourceIDs.joined(separator: "\n")
        errorMessagesJSON = try? encoder.encode(batch.errorMessages)
    }
}

private extension JSONEncoder {
    static var trendRadar: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
