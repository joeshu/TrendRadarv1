import Foundation

enum InsightTimeWindow: String, CaseIterable, Codable, Sendable {
    case current
    case daily
    case incremental

    var title: String {
        switch self {
        case .current: return "当前速览"
        case .daily: return "24 小时"
        case .incremental: return "增量变化"
        }
    }

    func includes(_ date: Date?, now: Date = Date(), since lastSnapshot: Date? = nil) -> Bool {
        guard let date else { return true }
        switch self {
        case .current: return true
        case .daily: return date >= now.addingTimeInterval(-86_400)
        case .incremental: return lastSnapshot.map { date > $0 } ?? true
        }
    }
}

struct InsightCitation: Codable, Equatable, Hashable, Identifiable, Sendable {
    let itemID: String
    let title: String
    let source: String
    let url: URL?

    var id: String { itemID }
}

struct InsightSentiment: Codable, Equatable, Hashable, Sendable {
    let positive: Double
    let neutral: Double
    let negative: Double
    let sampleCount: Int

    var isComputed: Bool { sampleCount > 0 }
    var score: Double { positive - negative }
}

struct InsightQueryResult: Codable, Equatable, Sendable {
    let answer: String
    let citations: [InsightCitation]
    let createdAt: Date
}
