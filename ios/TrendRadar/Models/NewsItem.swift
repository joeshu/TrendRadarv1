import Foundation

struct NewsItem: Codable, Identifiable, Hashable, Sendable {
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

struct RSSFeed: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let url: URL
}

struct PlatformSource: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var expectedDomain: String
    var isEnabled: Bool

    init(id: String, name: String, expectedDomain: String, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.expectedDomain = expectedDomain
        self.isEnabled = isEnabled
    }
}

struct ConfigFeed: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var url: String
    var isEnabled: Bool
    var maxAgeDays: Int

    init(id: String, name: String, url: String, isEnabled: Bool = true, maxAgeDays: Int = 0) {
        self.id = id
        self.name = name
        self.url = url
        self.isEnabled = isEnabled
        self.maxAgeDays = maxAgeDays
    }

    var rssFeed: RSSFeed? {
        guard let feedURL = URL(string: url.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        return RSSFeed(id: id, name: name, url: feedURL)
    }
}

struct ReportSettings: Codable, Equatable, Sendable {
    var mode = "current"
    var displayMode = "keyword"
    var sortByPositionFirst = false
    var rankThreshold = 5
    var maxNewsPerKeyword = 0
}

struct DisplaySettings: Codable, Equatable, Sendable {
    var showHotlist = true
    var showNewItems = false
    var showRSS = true
    var showStandalone = false
    var showAIAnalysis = true
    var standalonePlatforms: [String] = ["zhihu", "wallstreetcn-hot"]
    var standaloneRSSFeeds: [String] = []
    var standaloneMaxItems = 20
}

struct AISettings: Codable, Equatable, Sendable {
    var enabled = true
    var language = "Chinese"
    var filterMethod = "keyword"
    var prioritySortEnabled = true
    var batchSize = 200
    var batchInterval = 2
    var minimumScore = 0.7
    var reclassifyThreshold = 0.6
    var timeout = 120
    var temperature = 1.0
    var maxTokens = 5000
    var retries = 1
    var fallbackModels: [String] = []
    var interests: String = ""
}

struct NotificationSettings: Codable, Equatable, Sendable {
    var enabled = true
    var localAlerts = true
    var soundEnabled = true
}

struct AppSettings: Codable, Equatable, Sendable {
    var keywords: [String] = []
    var enabledFeedIDs: Set<String> = ["hn", "bbc"]
    var refreshInterval: Double = 60
    var timezone = "Asia/Shanghai"
    var showVersionUpdate = true
    var scheduleEnabled = true
    var schedulePreset = "night_owl"
    var platformsEnabled = true
    var platformAPIURL = ""
    var platformSources: [PlatformSource] = AppSettings.defaultPlatformSources
    var rssEnabled = true
    var rssFreshnessEnabled = true
    var rssMaxAgeDays = 1
    var customFeeds: [ConfigFeed] = AppSettings.defaultFeeds
    var report = ReportSettings()
    var display = DisplaySettings()
    var ai = AISettings()
    var notification = NotificationSettings()
    var globalFilterWords: [String] = ["震惊"]

    static let defaultFeeds = [
        ConfigFeed(id: "hn", name: "Hacker News", url: "https://hnrss.org/frontpage"),
        ConfigFeed(id: "bbc", name: "BBC News", url: "https://feeds.bbci.co.uk/news/rss.xml"),
        ConfigFeed(id: "nasa", name: "NASA", url: "https://www.nasa.gov/rss/dyn/breaking_news.rss", isEnabled: false)
    ]

    static let defaultPlatformSources = [
        PlatformSource(id: "toutiao", name: "今日头条", expectedDomain: "toutiao.com"),
        PlatformSource(id: "baidu", name: "百度热搜", expectedDomain: "baidu.com"),
        PlatformSource(id: "wallstreetcn-hot", name: "华尔街见闻", expectedDomain: "wallstreetcn.com"),
        PlatformSource(id: "thepaper", name: "澎湃新闻", expectedDomain: "thepaper.cn"),
        PlatformSource(id: "bilibili-hot-search", name: "bilibili 热搜", expectedDomain: "bilibili.com"),
        PlatformSource(id: "cls-hot", name: "财联社热门", expectedDomain: "cls.cn"),
        PlatformSource(id: "ifeng", name: "凤凰网", expectedDomain: "ifeng.com"),
        PlatformSource(id: "tieba", name: "贴吧", expectedDomain: "baidu.com"),
        PlatformSource(id: "weibo", name: "微博", expectedDomain: "weibo.com"),
        PlatformSource(id: "douyin", name: "抖音", expectedDomain: "douyin.com"),
        PlatformSource(id: "zhihu", name: "知乎", expectedDomain: "zhihu.com")
    ]

    private enum CodingKeys: String, CodingKey {
        case keywords, enabledFeedIDs, refreshInterval, timezone, showVersionUpdate
        case scheduleEnabled, schedulePreset, platformsEnabled, platformAPIURL, platformSources
        case rssEnabled, rssFreshnessEnabled, rssMaxAgeDays, customFeeds, report, display, ai
        case notification, globalFilterWords
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        keywords = try container.decodeIfPresent([String].self, forKey: .keywords) ?? []
        enabledFeedIDs = try container.decodeIfPresent(Set<String>.self, forKey: .enabledFeedIDs) ?? ["hn", "bbc"]
        refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 60
        timezone = try container.decodeIfPresent(String.self, forKey: .timezone) ?? "Asia/Shanghai"
        showVersionUpdate = try container.decodeIfPresent(Bool.self, forKey: .showVersionUpdate) ?? true
        scheduleEnabled = try container.decodeIfPresent(Bool.self, forKey: .scheduleEnabled) ?? true
        schedulePreset = try container.decodeIfPresent(String.self, forKey: .schedulePreset) ?? "night_owl"
        platformsEnabled = try container.decodeIfPresent(Bool.self, forKey: .platformsEnabled) ?? true
        platformAPIURL = try container.decodeIfPresent(String.self, forKey: .platformAPIURL) ?? ""
        platformSources = try container.decodeIfPresent([PlatformSource].self, forKey: .platformSources) ?? Self.defaultPlatformSources
        rssEnabled = try container.decodeIfPresent(Bool.self, forKey: .rssEnabled) ?? true
        rssFreshnessEnabled = try container.decodeIfPresent(Bool.self, forKey: .rssFreshnessEnabled) ?? true
        rssMaxAgeDays = try container.decodeIfPresent(Int.self, forKey: .rssMaxAgeDays) ?? 1
        customFeeds = try container.decodeIfPresent([ConfigFeed].self, forKey: .customFeeds) ?? Self.defaultFeeds
        report = try container.decodeIfPresent(ReportSettings.self, forKey: .report) ?? ReportSettings()
        display = try container.decodeIfPresent(DisplaySettings.self, forKey: .display) ?? DisplaySettings()
        ai = try container.decodeIfPresent(AISettings.self, forKey: .ai) ?? AISettings()
        notification = try container.decodeIfPresent(NotificationSettings.self, forKey: .notification) ?? NotificationSettings()
        globalFilterWords = try container.decodeIfPresent([String].self, forKey: .globalFilterWords) ?? ["震惊"]
    }
}
