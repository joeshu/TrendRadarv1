import Foundation
import SwiftData

@Model
final class HotNewsRecord {
    @Attribute(.unique) var id: String
    var title: String
    var urlString: String?
    var platformID: String
    var platformName: String
    var currentRank: Int
    var previousRank: Int?
    var publishedAt: Date?
    var extraInfo: String?
    var topicKey: String
    var firstSeenAt: Date
    var lastSeenAt: Date
    var isRead: Bool
    var isFavorite: Bool

    init(item: HotNewsItem, seenAt: Date = Date()) {
        id = item.id
        title = item.title
        urlString = item.url?.absoluteString
        platformID = item.platformID
        platformName = item.platformName
        currentRank = item.rank
        previousRank = item.previousRank
        publishedAt = item.publishedAt
        extraInfo = item.extraInfo
        topicKey = item.topicKey
        firstSeenAt = seenAt
        lastSeenAt = seenAt
        isRead = item.isRead
        isFavorite = item.isFavorite
    }

    func update(with item: HotNewsItem, seenAt: Date = Date()) {
        previousRank = currentRank
        currentRank = item.rank
        title = item.title
        urlString = item.url?.absoluteString
        publishedAt = item.publishedAt
        extraInfo = item.extraInfo
        topicKey = item.topicKey
        isRead = item.isRead
        isFavorite = item.isFavorite
        lastSeenAt = seenAt
    }

    var asItem: HotNewsItem {
        HotNewsItem(id: id, title: title, url: urlString.flatMap(URL.init(string:)), platformID: platformID, platformName: platformName, rank: currentRank, publishedAt: publishedAt, extraInfo: extraInfo, topicKey: topicKey, previousRank: previousRank, isRead: isRead, isFavorite: isFavorite)
    }
}

@Model
final class HotNewsTrendRecord {
    @Attribute(.unique) var id: String
    var hotNewsID: String
    var topicKey: String
    var platformID: String
    var rank: Int
    var capturedAt: Date

    init(item: HotNewsItem, capturedAt: Date = Date()) {
        id = UUID().uuidString
        hotNewsID = item.id
        topicKey = item.topicKey
        platformID = item.platformID
        rank = item.rank
        self.capturedAt = capturedAt
    }
}
