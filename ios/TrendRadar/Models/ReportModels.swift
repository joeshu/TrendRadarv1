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
    var hotlistCount: Int
    var rssCount: Int
    var hotlistPlatformCount: Int
    var rssSourceCount: Int

    init(newsCount: Int = 0, sourceCount: Int = 0, unreadCount: Int = 0, favoriteCount: Int = 0, keywordCount: Int = 0, hotlistCount: Int = 0, rssCount: Int = 0, hotlistPlatformCount: Int = 0, rssSourceCount: Int = 0) {
        self.newsCount = newsCount
        self.sourceCount = sourceCount
        self.unreadCount = unreadCount
        self.favoriteCount = favoriteCount
        self.keywordCount = keywordCount
        self.hotlistCount = hotlistCount
        self.rssCount = rssCount
        self.hotlistPlatformCount = hotlistPlatformCount
        self.rssSourceCount = rssSourceCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        newsCount = try c.decodeIfPresent(Int.self, forKey: .newsCount) ?? 0
        sourceCount = try c.decodeIfPresent(Int.self, forKey: .sourceCount) ?? 0
        unreadCount = try c.decodeIfPresent(Int.self, forKey: .unreadCount) ?? 0
        favoriteCount = try c.decodeIfPresent(Int.self, forKey: .favoriteCount) ?? 0
        keywordCount = try c.decodeIfPresent(Int.self, forKey: .keywordCount) ?? 0
        hotlistCount = try c.decodeIfPresent(Int.self, forKey: .hotlistCount) ?? 0
        rssCount = try c.decodeIfPresent(Int.self, forKey: .rssCount) ?? max(0, newsCount - hotlistCount)
        hotlistPlatformCount = try c.decodeIfPresent(Int.self, forKey: .hotlistPlatformCount) ?? 0
        rssSourceCount = try c.decodeIfPresent(Int.self, forKey: .rssSourceCount) ?? 0
    }

    private enum CodingKeys: String, CodingKey { case newsCount, sourceCount, unreadCount, favoriteCount, keywordCount, hotlistCount, rssCount, hotlistPlatformCount, rssSourceCount }
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
    var coreTrends: String? = nil
    var signals: String? = nil
    var failureMessage: String?
    var sentimentPositive: Double? = nil
    var sentimentNeutral: Double? = nil
    var sentimentNegative: Double? = nil
    var weakSignals: [String] = []
    var recommendation: String? = nil
    var sentimentControversy: String? = nil
    var rssInsights: String? = nil
    var standaloneSummaries: [String: String] = [:]

    var hasContent: Bool {
        let values = [content, coreTrends, signals, sentimentControversy, rssInsights, recommendation]
        return values.contains { value in
            guard let value else { return false }
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } || !standaloneSummaries.isEmpty
    }
}

struct StructuredAIAnalysis: Codable, Equatable, Hashable, Sendable {
    var overview: String
    var sentimentPositive: Double
    var sentimentNeutral: Double
    var sentimentNegative: Double
    var weakSignals: [String]
    var signals: String
    var recommendation: String
    var sentimentControversy: String
    var rssInsights: String
    var standaloneSummaries: [String: String]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        overview = try container.decodeIfPresent(String.self, forKey: .overview)
            ?? (try container.decodeIfPresent(String.self, forKey: .coreTrends))
            ?? ""
        sentimentPositive = try container.decodeIfPresent(Double.self, forKey: .sentimentPositive) ?? 0
        sentimentNeutral = try container.decodeIfPresent(Double.self, forKey: .sentimentNeutral) ?? 1
        sentimentNegative = try container.decodeIfPresent(Double.self, forKey: .sentimentNegative) ?? 0
        weakSignals = try container.decodeIfPresent([String].self, forKey: .weakSignals) ?? []
        signals = (try? container.decode(String.self, forKey: .signals)) ?? ""
        recommendation = try container.decodeIfPresent(String.self, forKey: .recommendation)
            ?? (try container.decodeIfPresent(String.self, forKey: .outlookStrategy))
            ?? ""
        sentimentControversy = try container.decodeIfPresent(String.self, forKey: .sentimentControversy) ?? ""
        rssInsights = try container.decodeIfPresent(String.self, forKey: .rssInsights) ?? ""
        standaloneSummaries = try container.decodeIfPresent([String: String].self, forKey: .standaloneSummaries) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(overview, forKey: .overview)
        try container.encode(sentimentPositive, forKey: .sentimentPositive)
        try container.encode(sentimentNeutral, forKey: .sentimentNeutral)
        try container.encode(sentimentNegative, forKey: .sentimentNegative)
        try container.encode(weakSignals, forKey: .weakSignals)
        try container.encode(signals, forKey: .signals)
        try container.encode(recommendation, forKey: .recommendation)
        try container.encode(sentimentControversy, forKey: .sentimentControversy)
        try container.encode(rssInsights, forKey: .rssInsights)
        try container.encode(standaloneSummaries, forKey: .standaloneSummaries)
    }

    private enum CodingKeys: String, CodingKey {
        case overview, coreTrends = "core_trends"
        case sentimentPositive, sentimentNeutral, sentimentNegative
        case weakSignals, signals
        case recommendation, outlookStrategy = "outlook_strategy"
        case sentimentControversy = "sentiment_controversy"
        case rssInsights = "rss_insights"
        case standaloneSummaries = "standalone_summaries"
    }

    var coreTrends: String { overview }
}

enum ReportSourceType: String, Codable, Sendable {
    case hotlist
    case rss
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
    var sourceType: ReportSourceType
    var rank: Int?

    init(id: String = UUID().uuidString, orderIndex: Int, sectionID: String, sectionTitle: String, keyword: String? = nil, item: NewsItem, sourceType: ReportSourceType = .rss, rank: Int? = nil) {
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
        self.sourceType = sourceType
        self.rank = rank
    }

    init(id: String = UUID().uuidString, orderIndex: Int, sectionID: String, sectionTitle: String, keyword: String? = nil, item: HotNewsItem) {
        self.id = id
        self.orderIndex = orderIndex
        self.sectionID = sectionID
        self.sectionTitle = sectionTitle
        self.keyword = keyword
        title = item.title
        source = item.platformName
        url = item.url
        publishedAt = item.publishedAt
        summary = item.extraInfo
        isRead = item.isRead
        isFavorite = item.isFavorite
        sourceType = .hotlist
        rank = item.rank
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        orderIndex = try c.decodeIfPresent(Int.self, forKey: .orderIndex) ?? 0
        sectionID = try c.decodeIfPresent(String.self, forKey: .sectionID) ?? "all"
        sectionTitle = try c.decodeIfPresent(String.self, forKey: .sectionTitle) ?? "全部情报"
        keyword = try c.decodeIfPresent(String.self, forKey: .keyword)
        title = try c.decode(String.self, forKey: .title)
        source = try c.decodeIfPresent(String.self, forKey: .source) ?? "未知来源"
        url = try c.decodeIfPresent(URL.self, forKey: .url)
        publishedAt = try c.decodeIfPresent(Date.self, forKey: .publishedAt)
        summary = try c.decodeIfPresent(String.self, forKey: .summary)
        isRead = try c.decodeIfPresent(Bool.self, forKey: .isRead) ?? false
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        sourceType = try c.decodeIfPresent(ReportSourceType.self, forKey: .sourceType) ?? .rss
        rank = try c.decodeIfPresent(Int.self, forKey: .rank)
    }

    private enum CodingKeys: String, CodingKey { case id, orderIndex, sectionID, sectionTitle, keyword, title, source, url, publishedAt, summary, isRead, isFavorite, sourceType, rank }
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
