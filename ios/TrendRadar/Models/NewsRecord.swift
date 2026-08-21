import Foundation
import SwiftData

@Model
final class NewsRecord {
    @Attribute(.unique) var id: String
    var title: String
    var source: String
    var urlString: String?
    var publishedAt: Date?
    var summary: String?
    var isRead: Bool
    var isFavorite: Bool

    init(from item: NewsItem) {
        id = item.id
        title = item.title
        source = item.source
        urlString = item.url?.absoluteString
        publishedAt = item.publishedAt
        summary = item.summary
        isRead = item.isRead
        isFavorite = item.isFavorite
    }

    func asNewsItem() -> NewsItem {
        NewsItem(
            id: id,
            title: title,
            source: source,
            url: urlString.flatMap(URL.init(string:)),
            publishedAt: publishedAt,
            summary: summary,
            isRead: isRead,
            isFavorite: isFavorite
        )
    }
}
