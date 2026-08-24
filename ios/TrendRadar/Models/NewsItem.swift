import Foundation

enum InboxState: String, Codable, CaseIterable, Sendable {
    case unprocessed
    case readLater
    case archived

    var title: String {
        switch self {
        case .unprocessed: return "未处理"
        case .readLater: return "稍后读"
        case .archived: return "已归档"
        }
    }

    var systemImage: String {
        switch self {
        case .unprocessed: return "tray"
        case .readLater: return "bookmark"
        case .archived: return "archivebox"
        }
    }
}

struct NewsItem: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let source: String
    let url: URL?
    let publishedAt: Date?
    var summary: String?
    var translatedTitle: String?
    var author: String?
    var body: String?
    var bodyCachedAt: Date?
    var isRead: Bool = false
    var isFavorite: Bool = false
    var inboxState: InboxState = .unprocessed

    private enum CodingKeys: String, CodingKey { case id, title, source, url, publishedAt, summary, translatedTitle, author, body, bodyCachedAt, isRead, isFavorite, inboxState }

    init(id: String = UUID().uuidString, title: String, source: String, url: URL? = nil, publishedAt: Date? = nil, summary: String? = nil, translatedTitle: String? = nil, author: String? = nil, body: String? = nil, bodyCachedAt: Date? = nil, isRead: Bool = false, isFavorite: Bool = false, inboxState: InboxState = .unprocessed) {
        self.id = id
        self.title = title
        self.source = source
        self.url = url
        self.publishedAt = publishedAt
        self.summary = summary
        self.translatedTitle = translatedTitle
        self.author = author
        self.body = body
        self.bodyCachedAt = bodyCachedAt
        self.isRead = isRead
        self.isFavorite = isFavorite
        self.inboxState = inboxState
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        source = try container.decode(String.self, forKey: .source)
        url = try container.decodeIfPresent(URL.self, forKey: .url)
        publishedAt = try container.decodeIfPresent(Date.self, forKey: .publishedAt)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        translatedTitle = try container.decodeIfPresent(String.self, forKey: .translatedTitle)
        author = try container.decodeIfPresent(String.self, forKey: .author)
        body = try container.decodeIfPresent(String.self, forKey: .body)
        bodyCachedAt = try container.decodeIfPresent(Date.self, forKey: .bodyCachedAt)
        isRead = try container.decodeIfPresent(Bool.self, forKey: .isRead) ?? false
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        inboxState = try container.decodeIfPresent(InboxState.self, forKey: .inboxState) ?? (isRead ? .archived : .unprocessed)
    }
}

struct RSSFeed: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let url: URL
    var requestTimeout: Int = 20
    var retryCount: Int = 3
    var userAgent: String = "TrendRadar/1.0"
    var requestHeaders: [String: String] = [:]
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
    var group: String
    var requestTimeout: Int
    var retryCount: Int
    var userAgent: String
    var requestHeaders: String

    private enum CodingKeys: String, CodingKey { case id, name, url, isEnabled, maxAgeDays, group, requestTimeout, retryCount, userAgent, requestHeaders }

    init(id: String, name: String, url: String, isEnabled: Bool = true, maxAgeDays: Int = 0, group: String = "未分组", requestTimeout: Int = 20, retryCount: Int = 3, userAgent: String = "TrendRadar/1.0", requestHeaders: String = "") {
        self.id = id
        self.name = name
        self.url = url
        self.isEnabled = isEnabled
        self.maxAgeDays = maxAgeDays
        self.group = group
        self.requestTimeout = requestTimeout
        self.retryCount = retryCount
        self.userAgent = userAgent
        self.requestHeaders = requestHeaders
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        url = try container.decode(String.self, forKey: .url)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        maxAgeDays = try container.decodeIfPresent(Int.self, forKey: .maxAgeDays) ?? 0
        group = try container.decodeIfPresent(String.self, forKey: .group) ?? "未分组"
        requestTimeout = min(max(try container.decodeIfPresent(Int.self, forKey: .requestTimeout) ?? 20, 5), 120)
        retryCount = min(max(try container.decodeIfPresent(Int.self, forKey: .retryCount) ?? 3, 1), 5)
        userAgent = try container.decodeIfPresent(String.self, forKey: .userAgent) ?? "TrendRadar/1.0"
        requestHeaders = try container.decodeIfPresent(String.self, forKey: .requestHeaders) ?? ""
    }

    var rssFeed: RSSFeed? {
        guard let feedURL = URL(string: url.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        let headers = requestHeaders.components(separatedBy: .newlines).reduce(into: [String: String]()) { result, line in
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2, !parts[0].isEmpty { result[parts[0]] = parts[1] }
        }
        return RSSFeed(id: id, name: name, url: feedURL, requestTimeout: requestTimeout, retryCount: retryCount, userAgent: userAgent, requestHeaders: headers)
    }
}

struct ReportSettings: Codable, Equatable, Sendable {
    var mode = "current"
    var displayMode = "keyword"
    var sortByPositionFirst = false
    var rankThreshold = 5
    var maxNewsPerKeyword = 0
}

enum AppAppearance: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case dark
    case light

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .dark: return "深色"
        case .light: return "浅色"
        }
    }
}

enum AppFontStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case rounded
    case serif

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "系统黑体"
        case .rounded: return "圆体"
        case .serif: return "阅读宋体"
        }
    }
}

struct DisplaySettings: Codable, Equatable, Sendable {
    var showHotlist = true
    var showNewItems = false
    var showRSS = true
    var showStandalone = false
    var showAIAnalysis = true
    var appearance = AppAppearance.dark
    var fontStyle = AppFontStyle.system
    var highContrast = false
    var reduceTransparency = false
    /// 全局字体倍率，映射到系统 Dynamic Type 等级。
    var fontScale = 1.0
    /// 全局 UI 密度，控制表单行高和控件尺寸。
    var uiScale = 1.0
    /// 主页面卡片之间的垂直间距。
    var cardSpacing = 14.0
    var regionOrder: [String] = ["new_items", "hotlist", "rss", "standalone", "ai_analysis"]
    var standalonePlatforms: [String] = ["zhihu", "wallstreetcn-hot"]
    var standaloneRSSFeeds: [String] = []
    var standaloneMaxItems = 20

    private enum CodingKeys: String, CodingKey {
        case showHotlist, showNewItems, showRSS, showStandalone, showAIAnalysis
        case appearance, fontStyle, highContrast, reduceTransparency
        case fontScale, uiScale, cardSpacing, regionOrder, standalonePlatforms
        case standaloneRSSFeeds, standaloneMaxItems
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        showHotlist = try c.decodeIfPresent(Bool.self, forKey: .showHotlist) ?? true
        showNewItems = try c.decodeIfPresent(Bool.self, forKey: .showNewItems) ?? false
        showRSS = try c.decodeIfPresent(Bool.self, forKey: .showRSS) ?? true
        showStandalone = try c.decodeIfPresent(Bool.self, forKey: .showStandalone) ?? false
        showAIAnalysis = try c.decodeIfPresent(Bool.self, forKey: .showAIAnalysis) ?? true
        appearance = try c.decodeIfPresent(AppAppearance.self, forKey: .appearance) ?? .dark
        fontStyle = try c.decodeIfPresent(AppFontStyle.self, forKey: .fontStyle) ?? .system
        highContrast = try c.decodeIfPresent(Bool.self, forKey: .highContrast) ?? false
        reduceTransparency = try c.decodeIfPresent(Bool.self, forKey: .reduceTransparency) ?? false
        fontScale = min(max(try c.decodeIfPresent(Double.self, forKey: .fontScale) ?? 1.0, 0.85), 1.30)
        uiScale = min(max(try c.decodeIfPresent(Double.self, forKey: .uiScale) ?? 1.0, 0.90), 1.15)
        cardSpacing = min(max(try c.decodeIfPresent(Double.self, forKey: .cardSpacing) ?? 14.0, 8), 24)
        regionOrder = try c.decodeIfPresent([String].self, forKey: .regionOrder) ?? ["new_items", "hotlist", "rss", "standalone", "ai_analysis"]
        standalonePlatforms = try c.decodeIfPresent([String].self, forKey: .standalonePlatforms) ?? ["zhihu", "wallstreetcn-hot"]
        standaloneRSSFeeds = try c.decodeIfPresent([String].self, forKey: .standaloneRSSFeeds) ?? []
        standaloneMaxItems = try c.decodeIfPresent(Int.self, forKey: .standaloneMaxItems) ?? 20
    }
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
    var filterPromptFile = "prompt.txt"
    var extractPromptFile = "extract_prompt.txt"
    var updateTagsPromptFile = "update_tags_prompt.txt"
    var interestTags: [AIInterestTag] = []
}

struct AIInterestTag: Codable, Equatable, Hashable, Sendable, Identifiable {
    var id: Int
    var tag: String
    var description: String
}

struct AIAnalysisSettings: Codable, Equatable, Sendable {
    var enabled = true
    var language = "Chinese"
    var promptFile = "ai_analysis_prompt.txt"
    var mode = "follow_report"
    var maxNewsForAnalysis = 150
    var includeRSS = true
    var includeStandalone = true
    var includeRankTimeline = true
}

struct AITranslationSettings: Codable, Equatable, Sendable {
    var enabled = true
    var language = "中文"
    var promptFile = "ai_translation_prompt.txt"
    var batchSize = 100
    var batchInterval = 2
    var translateHotlist = false
    var translateRSS = true
    var translateStandalone = true
}

struct NotificationChannelSettings: Codable, Equatable, Sendable {
    var feishuWebhook = ""
    var dingtalkWebhook = ""
    var weworkWebhook = ""
    var weworkMessageType = "markdown"
    var telegramBotToken = ""
    var telegramChatID = ""
    var emailFrom = ""
    var emailTo = ""
    var emailSMTPServer = ""
    var emailSMTPPort = ""
    var ntfyServerURL = "https://ntfy.sh"
    var ntfyTopic = ""
    var barkURL = ""
    var slackWebhook = ""
    var genericWebhook = ""
    var genericPayloadTemplate = ""
}

struct StorageSettings: Codable, Equatable, Sendable {
    var backend = "auto"
    var sqliteEnabled = true
    var txtEnabled = false
    var htmlEnabled = true
    var localDataDirectory = "output"
    var localRetentionDays = 0
    var remoteRetentionDays = 0
    var remoteEndpointURL = ""
    var remoteBucketName = ""
    var remoteRegion = ""
    var pullEnabled = false
    var pullDays = 7
}

struct CrawlerAdvancedSettings: Codable, Equatable, Sendable {
    var requestIntervalMilliseconds = 2000
    var useProxy = false
    var defaultProxy = "http://127.0.0.1:10801"
}

struct RSSAdvancedSettings: Codable, Equatable, Sendable {
    var requestIntervalMilliseconds = 1000
    var timeout = 15
    var useProxy = false
    var proxyURL = ""
}

struct AdvancedSettings: Codable, Equatable, Sendable {
    var debug = false
    var versionCheckURL = "https://raw.githubusercontent.com/sansan0/TrendRadar/refs/heads/master/version"
    var mcpVersionCheckURL = "https://raw.githubusercontent.com/sansan0/TrendRadar/refs/heads/master/version_mcp"
    var configsVersionCheckURL = "https://raw.githubusercontent.com/sansan0/TrendRadar/refs/heads/master/version_configs"
    var crawler = CrawlerAdvancedSettings()
    var rss = RSSAdvancedSettings()
    var rankWeight = 0.6
    var frequencyWeight = 0.3
    var hotnessWeight = 0.1
    var maxAccountsPerChannel = 3
    var defaultBatchSize = 4000
    var dingtalkBatchSize = 20000
    var feishuBatchSize = 30000
    var barkBatchSize = 4000
    var slackBatchSize = 4000
    var batchSendInterval = 3
    var feishuMessageSeparator = "━━━━━━━━━━━━━━━━"
}

struct NotificationSettings: Codable, Equatable, Sendable {
    var enabled = true
    var localAlerts = true
    var soundEnabled = true
    var channels = NotificationChannelSettings()
}

struct AppSettings: Codable, Equatable, Sendable {
    static let defaultPlatformAPIURL = "https://newsnow.vercel.app/api"
    static let legacyPlatformAPIURL = "https://newsnow.busiyi.world/api"

    static func effectivePlatformAPIURL(_ configured: String) -> String {
        let value = configured.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let legacy = legacyPlatformAPIURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return value.isEmpty || value == legacy ? defaultPlatformAPIURL : value
    }

    var keywords: [String] = []
    var enabledFeedIDs: Set<String> = ["hn", "bbc"]
    var refreshInterval: Double = 60
    var timezone = "Asia/Shanghai"
    var showVersionUpdate = true
    var scheduleEnabled = true
    var schedulePreset = "night_owl"
    var platformsEnabled = true
    var platformAPIURL = AppSettings.defaultPlatformAPIURL
    var platformSources: [PlatformSource] = AppSettings.defaultPlatformSources
    var rssEnabled = true
    var rssFreshnessEnabled = true
    var rssMaxAgeDays = 1
    var customFeeds: [ConfigFeed] = AppSettings.defaultFeeds
    var report = ReportSettings()
    var display = DisplaySettings()
    var ai = AISettings()
    var aiAnalysis = AIAnalysisSettings()
    var aiTranslation = AITranslationSettings()
    var notification = NotificationSettings()
    var storage = StorageSettings()
    var advanced = AdvancedSettings()
    var globalFilterWords: [String] = ["震惊"]

    static let defaultFeeds = [
        ConfigFeed(id: "hn", name: "Hacker News", url: "https://hnrss.org/frontpage"),
        ConfigFeed(id: "bbc", name: "BBC News", url: "https://feeds.bbci.co.uk/news/rss.xml"),
        ConfigFeed(id: "ruanyifeng", name: "阮一峰的网络日志", url: "http://www.ruanyifeng.com/blog/atom.xml", isEnabled: false),
        ConfigFeed(id: "yahoo-finance", name: "雅虎财经", url: "https://finance.yahoo.com/news/rssindex"),
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
        PlatformSource(id: "zhihu", name: "知乎", expectedDomain: "zhihu.com"),
        PlatformSource(id: "36kr", name: "36氪", expectedDomain: "36kr.com"),
        PlatformSource(id: "ithome", name: "IT之家", expectedDomain: "ithome.com"),
        PlatformSource(id: "hupu", name: "虎扑", expectedDomain: "hupu.com"),
        PlatformSource(id: "nga", name: "NGA", expectedDomain: "nga.cn"),
        PlatformSource(id: "juejin", name: "掘金", expectedDomain: "juejin.cn"),
        PlatformSource(id: "sspai", name: "少数派", expectedDomain: "sspai.com"),
        PlatformSource(id: "coolapk", name: "酷安", expectedDomain: "coolapk.com"),
        PlatformSource(id: "v2ex", name: "V2EX", expectedDomain: "v2ex.com"),
        PlatformSource(id: "github-trending-today", name: "GitHub Trending", expectedDomain: "github.com"),
        PlatformSource(id: "producthunt", name: "Product Hunt", expectedDomain: "producthunt.com"),
        PlatformSource(id: "hackernews", name: "Hacker News", expectedDomain: "ycombinator.com"),
        PlatformSource(id: "reddit", name: "Reddit", expectedDomain: "reddit.com"),
        PlatformSource(id: "youtube", name: "YouTube", expectedDomain: "youtube.com"),
        PlatformSource(id: "tiktok", name: "TikTok", expectedDomain: "tiktok.com"),
        PlatformSource(id: "kuaishou", name: "快手", expectedDomain: "kuaishou.com"),
        PlatformSource(id: "netease-news", name: "网易新闻", expectedDomain: "163.com"),
        PlatformSource(id: "qq-news", name: "腾讯新闻", expectedDomain: "qq.com"),
        PlatformSource(id: "sina-news", name: "新浪新闻", expectedDomain: "sina.com.cn"),
        PlatformSource(id: "sohu-news", name: "搜狐新闻", expectedDomain: "sohu.com"),
        PlatformSource(id: "xueqiu", name: "雪球", expectedDomain: "xueqiu.com"),
        PlatformSource(id: "eastmoney", name: "东方财富", expectedDomain: "eastmoney.com"),
        PlatformSource(id: "yiche", name: "易车", expectedDomain: "yiche.com"),
        PlatformSource(id: "autohome", name: "汽车之家", expectedDomain: "autohome.com.cn"),
        PlatformSource(id: "douban", name: "豆瓣", expectedDomain: "douban.com"),
        PlatformSource(id: "acfun", name: "AcFun", expectedDomain: "acfun.cn"),
        PlatformSource(id: "qq-video", name: "腾讯视频", expectedDomain: "qq.com"),
        PlatformSource(id: "youku", name: "优酷", expectedDomain: "youku.com"),
        PlatformSource(id: "google", name: "Google 热搜", expectedDomain: "google.com"),
        PlatformSource(id: "wikipedia", name: "Wikipedia", expectedDomain: "wikipedia.org"),
        PlatformSource(id: "techcrunch", name: "TechCrunch", expectedDomain: "techcrunch.com"),
        PlatformSource(id: "theverge", name: "The Verge", expectedDomain: "theverge.com"),
        PlatformSource(id: "nytimes", name: "New York Times", expectedDomain: "nytimes.com"),
        PlatformSource(id: "bbc", name: "BBC", expectedDomain: "bbc.com")
    ]

    private enum CodingKeys: String, CodingKey {
        case keywords, enabledFeedIDs, refreshInterval, timezone, showVersionUpdate
        case scheduleEnabled, schedulePreset, platformsEnabled, platformAPIURL, platformSources
        case rssEnabled, rssFreshnessEnabled, rssMaxAgeDays, customFeeds, report, display, ai
        case aiAnalysis, aiTranslation, notification, storage, advanced, globalFilterWords
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
         let storedPlatformAPIURL = try container.decodeIfPresent(String.self, forKey: .platformAPIURL) ?? Self.defaultPlatformAPIURL
        platformAPIURL = storedPlatformAPIURL == Self.legacyPlatformAPIURL ? Self.defaultPlatformAPIURL : storedPlatformAPIURL
         let configuredSources = try container.decodeIfPresent([PlatformSource].self, forKey: .platformSources) ?? []
         let configuredIDs = Set(configuredSources.map(\.id))
         platformSources = configuredSources + Self.defaultPlatformSources.filter { !configuredIDs.contains($0.id) }
        rssEnabled = try container.decodeIfPresent(Bool.self, forKey: .rssEnabled) ?? true
        rssFreshnessEnabled = try container.decodeIfPresent(Bool.self, forKey: .rssFreshnessEnabled) ?? true
        rssMaxAgeDays = try container.decodeIfPresent(Int.self, forKey: .rssMaxAgeDays) ?? 1
        customFeeds = try container.decodeIfPresent([ConfigFeed].self, forKey: .customFeeds) ?? Self.defaultFeeds
        report = try container.decodeIfPresent(ReportSettings.self, forKey: .report) ?? ReportSettings()
        display = try container.decodeIfPresent(DisplaySettings.self, forKey: .display) ?? DisplaySettings()
        ai = try container.decodeIfPresent(AISettings.self, forKey: .ai) ?? AISettings()
        aiAnalysis = try container.decodeIfPresent(AIAnalysisSettings.self, forKey: .aiAnalysis) ?? AIAnalysisSettings()
        aiTranslation = try container.decodeIfPresent(AITranslationSettings.self, forKey: .aiTranslation) ?? AITranslationSettings()
        notification = try container.decodeIfPresent(NotificationSettings.self, forKey: .notification) ?? NotificationSettings()
        storage = try container.decodeIfPresent(StorageSettings.self, forKey: .storage) ?? StorageSettings()
        advanced = try container.decodeIfPresent(AdvancedSettings.self, forKey: .advanced) ?? AdvancedSettings()
        globalFilterWords = try container.decodeIfPresent([String].self, forKey: .globalFilterWords) ?? ["震惊"]
    }
}
