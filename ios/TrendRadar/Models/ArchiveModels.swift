import Foundation
import CryptoKit

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
    var body: String?
    var capturedAt: Date
    var isFavorite: Bool
    var snapshotVersion: String?
    var contentSize: Int?
    var checksum: String?

    init(resourceID: String, kind: ArchiveResourceKind, title: String, source: String, url: URL? = nil, summary: String? = nil, body: String? = nil, capturedAt: Date = Date(), isFavorite: Bool = true, snapshotVersion: String? = "v1.0", contentSize: Int? = nil, checksum: String? = nil) {
        self.resourceID = resourceID
        self.kind = kind
        self.id = "\(kind.rawValue):\(resourceID)"
        self.title = title
        self.source = source
        self.url = url
        self.summary = summary
        self.body = body
        self.capturedAt = capturedAt
        self.isFavorite = isFavorite
        self.snapshotVersion = snapshotVersion
        let payload = [title, source, summary ?? "", body ?? "", url?.absoluteString ?? ""].joined(separator: "\n")
        let data = Data(payload.utf8)
        self.contentSize = contentSize ?? data.count
        self.checksum = checksum ?? SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    var searchableText: String { [title, source, summary ?? ""].joined(separator: " ") }

    var shareText: String {
        [title, source, summary, body, url?.absoluteString].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    init(news: NewsItem) {
        self.init(resourceID: news.id, kind: .rss, title: news.title, source: news.source, url: news.url, summary: news.summary, body: news.body, capturedAt: Date(), isFavorite: news.isFavorite)
    }

    init(topic: HotNewsTopic) {
        let best = topic.items.min(by: { $0.rank < $1.rank })
        self.init(resourceID: topic.id, kind: .hotlist, title: topic.title, source: topic.platforms.joined(separator: " · "), url: best?.url, summary: "最佳排名 #\(topic.bestRank) · \(topic.platformCount) 个平台", capturedAt: best?.publishedAt ?? Date(), isFavorite: true)
    }

    init(report: ReportSummary) {
        self.init(resourceID: report.id.uuidString, kind: .report, title: report.title, source: report.type.displayName, summary: "\(report.newsCount) 条情报 · \(report.sourceCount) 个来源", capturedAt: report.generatedAt, isFavorite: report.isFavorite)
    }
}
