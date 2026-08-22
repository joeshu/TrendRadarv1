import Foundation

struct HotNewsItem: Codable, Equatable, Hashable, Identifiable, Sendable {
    let id: String
    let title: String
    let url: URL?
    let platformID: String
    let platformName: String
    var rank: Int
    let publishedAt: Date?
    let extraInfo: String?
    let topicKey: String
    var firstSeenAt: Date? = nil
    var previousRank: Int?
    var isRead: Bool
    var isFavorite: Bool

    init(
        id: String,
        title: String,
        url: URL?,
        platformID: String,
        platformName: String,
        rank: Int,
        publishedAt: Date?,
        extraInfo: String?,
        topicKey: String,
        firstSeenAt: Date? = nil,
        previousRank: Int? = nil,
        isRead: Bool = false,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.platformID = platformID
        self.platformName = platformName
        self.rank = rank
        self.publishedAt = publishedAt
        self.extraInfo = extraInfo
        self.topicKey = topicKey
        self.firstSeenAt = firstSeenAt
        self.previousRank = previousRank
        self.isRead = isRead
        self.isFavorite = isFavorite
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, url, platformID, platformName, rank, publishedAt, extraInfo, topicKey, firstSeenAt, previousRank, isRead, isFavorite
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        url = try container.decodeIfPresent(URL.self, forKey: .url)
        platformID = try container.decode(String.self, forKey: .platformID)
        platformName = try container.decode(String.self, forKey: .platformName)
        rank = try container.decode(Int.self, forKey: .rank)
        publishedAt = try container.decodeIfPresent(Date.self, forKey: .publishedAt)
        extraInfo = try container.decodeIfPresent(String.self, forKey: .extraInfo)
        topicKey = try container.decode(String.self, forKey: .topicKey)
        firstSeenAt = try container.decodeIfPresent(Date.self, forKey: .firstSeenAt)
        previousRank = try container.decodeIfPresent(Int.self, forKey: .previousRank)
        isRead = try container.decodeIfPresent(Bool.self, forKey: .isRead) ?? false
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
    }

    var trend: HotNewsTrend {
        guard let previousRank else { return .new }
        if rank < previousRank { return .up }
        if rank > previousRank { return .down }
        return .stable
    }
}

enum HotNewsTrend: String, Codable, Sendable {
    case up
    case down
    case stable
    case new
}

struct HotNewsAnomaly: Identifiable, Hashable, Sendable {
    let topicKey: String
    let title: String
    let rank: Int
    let previousRank: Int?
    let change: Int
    let platforms: [String]

    var id: String { topicKey }

    var isRising: Bool { change > 0 }
}

struct HotNewsTopic: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let items: [HotNewsItem]

    var platforms: [String] { Array(Set(items.map(\.platformName))).sorted() }
    var bestRank: Int { items.map(\.rank).min() ?? 0 }

    var platformCount: Int { platforms.count }

    var strongestTrend: HotNewsTrend {
        if items.contains(where: { $0.trend == .up }) { return .up }
        if items.contains(where: { $0.trend == .down }) { return .down }
        if !items.isEmpty && items.allSatisfy({ $0.trend == .new }) { return .new }
        return .stable
    }

    var firstSeenAt: Date? {
        items.compactMap(\.firstSeenAt).min()
    }

    var duration: TimeInterval? {
        guard let firstSeenAt else { return nil }
        return max(0, Date().timeIntervalSince(firstSeenAt))
    }
}

struct NewsNowResponse: Decodable, Sendable {
    let status: String?
    let id: String?
    let updatedTime: Int64?
    let items: [NewsNowItem]
}

struct NewsNowItem: Decodable, Sendable {
    let id: String
    let title: String
    let url: URL?
    let pubDate: Int64?
    let extra: NewsNowExtra?
}

struct NewsNowExtra: Decodable, Sendable {
    let info: String?

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            info = value
            return
        }
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let value = try? container.decode(String.self, forKey: .info) {
            info = value
            return
        }
        info = nil
    }

    private enum CodingKeys: String, CodingKey { case info }
}

struct HotNewsRecordSnapshot: Sendable {
    let item: HotNewsItem
    let seenAt: Date
}
