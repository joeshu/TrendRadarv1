import Foundation

struct NewsItem: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let source: String
    let url: URL?
    let publishedAt: Date?
    var summary: String?
    var isRead: Bool = false
    var isFavorite: Bool = false

    init(id: String = UUID().uuidString, title: String, source: String, url: URL? = nil, publishedAt: Date? = nil, summary: String? = nil, isRead: Bool = false, isFavorite: Bool = false) {
        self.id = id
        self.title = title
        self.source = source
        self.url = url
        self.publishedAt = publishedAt
        self.summary = summary
        self.isRead = isRead
        self.isFavorite = isFavorite
    }
}

struct RSSFeed: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let url: URL
}

struct AppSettings: Codable, Equatable {
    var keywords: [String] = []
    var enabledFeedIDs: Set<String> = ["hn", "bbc"]
    var refreshInterval: Double = 60
}
