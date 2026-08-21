import Foundation

enum ReportType: String, Codable, CaseIterable, Hashable, Sendable {
    case current
    case daily
    case incremental
    case manual

    var displayName: String {
        switch self {
        case .current: return "当前榜单"
        case .daily: return "当日汇总"
        case .incremental: return "增量报告"
        case .manual: return "手动报告"
        }
    }
}

enum ReportTrigger: String, Codable, Hashable, Sendable {
    case manual
    case foregroundRefresh
    case backgroundRefresh
    case scheduled
}

enum ReportStatus: String, Codable, Hashable, Sendable {
    case generating
    case completed
    case failed
}

struct ReportStatistics: Codable, Equatable, Hashable, Sendable {
    var newsCount: Int
    var sourceCount: Int
    var unreadCount: Int
    var favoriteCount: Int
    var keywordCount: Int

    init(newsCount: Int = 0, sourceCount: Int = 0, unreadCount: Int = 0, favoriteCount: Int = 0, keywordCount: Int = 0) {
        self.newsCount = newsCount
        self.sourceCount = sourceCount
        self.unreadCount = unreadCount
        self.favoriteCount = favoriteCount
        self.keywordCount = keywordCount
    }
}

struct ReportSettingsSnapshot: Codable, Equatable, Hashable, Sendable {
    var reportType: ReportType
    var reportMode: String
    var displayMode: String
    var filterMethod: String
    var regionOrder: [String]
    var keywords: [String]
    var generatedAt: Date

    init(settings: AppSettings, reportType: ReportType, generatedAt: Date) {
        self.reportType = reportType
        reportMode = settings.report.mode
        displayMode = settings.report.displayMode
        filterMethod = settings.ai.filterMethod
        regionOrder = settings.display.regionOrder
        keywords = settings.keywords
        self.generatedAt = generatedAt
    }
}

struct ReportAIAnalysis: Codable, Equatable, Hashable, Sendable {
    var enabled: Bool
    var model: String?
    var language: String
    var content: String?
    var failureMessage: String?
    var sentimentPositive: Double? = nil
    var sentimentNeutral: Double? = nil
    var sentimentNegative: Double? = nil
    var weakSignals: [String] = []
    var recommendation: String? = nil

    var hasContent: Bool {
        guard let content else { return false }
        return !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct StructuredAIAnalysis: Codable, Equatable, Hashable, Sendable {
    var overview: String
    var sentimentPositive: Double
    var sentimentNeutral: Double
    var sentimentNegative: Double
    var weakSignals: [String]
    var recommendation: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        overview = try container.decodeIfPresent(String.self, forKey: .overview)
            ?? (try container.decodeIfPresent(String.self, forKey: .coreTrends))
            ?? ""
        sentimentPositive = try container.decodeIfPresent(Double.self, forKey: .sentimentPositive) ?? 0
        sentimentNeutral = try container.decodeIfPresent(Double.self, forKey: .sentimentNeutral) ?? 1
        sentimentNegative = try container.decodeIfPresent(Double.self, forKey: .sentimentNegative) ?? 0
        weakSignals = try container.decodeIfPresent([String].self, forKey: .weakSignals)
            ?? (try container.decodeIfPresent([String].self, forKey: .signals))
            ?? []
        recommendation = try container.decodeIfPresent(String.self, forKey: .recommendation)
            ?? (try container.decodeIfPresent(String.self, forKey: .outlookStrategy))
            ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case overview, coreTrends = "core_trends"
        case sentimentPositive, sentimentNeutral, sentimentNegative
        case weakSignals, signals
        case recommendation, outlookStrategy = "outlook_strategy"
    }
}

struct ReportSection: Codable, Equatable, Hashable, Identifiable, Sendable {
    let id: String
    var title: String
    var items: [ReportItemSnapshot]
}

struct ReportItemSnapshot: Codable, Equatable, Hashable, Identifiable, Sendable {
    let id: String
    var orderIndex: Int
    var sectionID: String
    var sectionTitle: String
    var keyword: String?
    var title: String
    var source: String
    var url: URL?
    var publishedAt: Date?
    var summary: String?
    var isRead: Bool
    var isFavorite: Bool

    init(id: String = UUID().uuidString, orderIndex: Int, sectionID: String, sectionTitle: String, keyword: String? = nil, item: NewsItem) {
        self.id = id
        self.orderIndex = orderIndex
        self.sectionID = sectionID
        self.sectionTitle = sectionTitle
        self.keyword = keyword
        title = item.title
        source = item.source
        url = item.url
        publishedAt = item.publishedAt
        summary = item.summary
        isRead = item.isRead
        isFavorite = item.isFavorite
    }
}

struct ReportSummary: Codable, Equatable, Hashable, Identifiable, Sendable {
    let id: UUID
    var title: String
    var type: ReportType
    var generatedAt: Date
    var status: ReportStatus
    var newsCount: Int
    var sourceCount: Int
    var hasAIAnalysis: Bool
    var isFavorite: Bool
    var searchableText: String = ""
}

struct ReportDetail: Codable, Equatable, Hashable, Identifiable, Sendable {
    let id: UUID
    var title: String
    var type: ReportType
    var trigger: ReportTrigger
    var generatedAt: Date
    var status: ReportStatus
    var statistics: ReportStatistics
    var settingsSnapshot: ReportSettingsSnapshot
    var aiAnalysis: ReportAIAnalysis?
    var sections: [ReportSection]
    var isFavorite: Bool
    var failureMessage: String?

    var summary: ReportSummary {
        let searchableText = sections.flatMap(\.items).map { item in
            [item.title, item.source, item.summary ?? ""].joined(separator: " ")
        }.joined(separator: " ")
        return ReportSummary(
            id: id,
            title: title,
            type: type,
            generatedAt: generatedAt,
            status: status,
            newsCount: statistics.newsCount,
            sourceCount: statistics.sourceCount,
            hasAIAnalysis: aiAnalysis?.hasContent == true,
            isFavorite: isFavorite,
            searchableText: searchableText
        )
    }
}
