import Foundation

struct HotNewsItem: Codable, Equatable, Hashable, Identifiable, Sendable {
    let id: String
    let title: String
    let url: URL?
    let platformID: String
    let platformName: String
    let rank: Int
    let publishedAt: Date?
    let extraInfo: String?
    let topicKey: String
    var previousRank: Int?
    var isRead: Bool
    var isFavorite: Bool

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
