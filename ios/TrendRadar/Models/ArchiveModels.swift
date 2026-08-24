import Foundation

enum ArchiveResourceKind: String, Codable, CaseIterable, Sendable {
    case hotlist
    case rss
    case report

    var title: String {
        switch self {
        case .hotlist: return "趋势"
        case .rss: return "新闻"
        case .report: return "报告"
        }
    }

    var systemImage: String {
        switch self {
        case .hotlist: return "waveform.path.ecg"
        case .rss: return "newspaper"
        case .report: return "doc.text"
        }
    }
}

struct ArchiveResource: Codable, Equatable, Hashable, Identifiable, Sendable {
    let id: String
    let resourceID: String
    let kind: ArchiveResourceKind
    var title: String
    var source: String
    var url: URL?
    var summary: String?
    var capturedAt: Date
    var isFavorite: Bool

    init(resourceID: String, kind: ArchiveResourceKind, title: String, source: String, url: URL? = nil, summary: String? = nil, capturedAt: Date = Date(), isFavorite: Bool = true) {
        self.resourceID = resourceID
        self.kind = kind
        self.id = "\(kind.rawValue):\(resourceID)"
        self.title = title
        self.source = source
        self.url = url
        self.summary = summary
        self.capturedAt = capturedAt
        self.isFavorite = isFavorite
    }

    var searchableText: String { [title, source, summary ?? ""].joined(separator: " ") }

    var shareText: String {
        [title, source, summary, url?.absoluteString].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    init(news: NewsItem) {
        self.init(resourceID: news.id, kind: .rss, title: news.title, source: news.source, url: news.url, summary: news.summary, capturedAt: news.publishedAt ?? Date(), isFavorite: news.isFavorite)
    }

    init(topic: HotNewsTopic) {
        let best = topic.items.min(by: { $0.rank < $1.rank })
        self.init(resourceID: topic.id, kind: .hotlist, title: topic.title, source: topic.platforms.joined(separator: " · "), url: best?.url, summary: "最佳排名 #\(topic.bestRank) · \(topic.platformCount) 个平台", capturedAt: best?.publishedAt ?? Date(), isFavorite: true)
    }

    init(report: ReportSummary) {
        self.init(resourceID: report.id.uuidString, kind: .report, title: report.title, source: report.type.displayName, summary: "\(report.newsCount) 条情报 · \(report.sourceCount) 个来源", capturedAt: report.generatedAt, isFavorite: report.isFavorite)
    }
}
