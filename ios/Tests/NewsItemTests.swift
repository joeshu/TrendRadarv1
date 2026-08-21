import XCTest
@testable import TrendRadar

final class NewsItemTests: XCTestCase {
    private let feed = RSSFeed(id: "test", name: "Test Feed", url: URL(string: "https://example.com/rss")!)

    func testNewsItemHasStableIdentifier() {
        let item = NewsItem(title: "Test", source: "Unit Test")
        XCTAssertFalse(item.id.isEmpty)
        XCTAssertEqual(item.title, "Test")
    }

    func testNewsItemPreservesReadAndFavoriteState() {
        let item = NewsItem(id: "stable", title: "Test", source: "Unit Test", isRead: true, isFavorite: true)
        let record = NewsRecord(from: item)
        let restored = record.asNewsItem()
        XCTAssertTrue(restored.isRead)
        XCTAssertTrue(restored.isFavorite)
        XCTAssertEqual(restored.id, "stable")
    }

    func testDefaultSettingsEnablePrimaryFeeds() {
        let settings = AppSettings()
        XCTAssertTrue(settings.enabledFeedIDs.contains("hn"))
        XCTAssertTrue(settings.enabledFeedIDs.contains("bbc"))
        XCTAssertEqual(settings.refreshInterval, 60)
        XCTAssertEqual(settings.schedulePreset, "night_owl")
        XCTAssertTrue(settings.platformSources.contains { $0.id == "zhihu" })
        XCTAssertEqual(settings.aiTranslation.batchInterval, 2)
    }

    func testHotNewsTrendCalculatesRankDirection() {
        let item = HotNewsItem(id: "weibo:1", title: "Trend", url: nil, platformID: "weibo", platformName: "微博", rank: 2, publishedAt: nil, extraInfo: nil, topicKey: "trend", previousRank: 5, isRead: false, isFavorite: false)
        XCTAssertEqual(item.trend, .up)
        XCTAssertEqual(HotNewsItem(id: "x", title: "x", url: nil, platformID: "p", platformName: "P", rank: 5, publishedAt: nil, extraInfo: nil, topicKey: "x", previousRank: 2, isRead: false, isFavorite: false).trend, .down)
        XCTAssertEqual(HotNewsItem(id: "y", title: "y", url: nil, platformID: "p", platformName: "P", rank: 1, publishedAt: nil, extraInfo: nil, topicKey: "y", previousRank: nil, isRead: false, isFavorite: false).trend, .new)
    }

    func testHotNewsAnomalyUsesThreeRankChangeThreshold() {
        let rising = HotNewsItem(id: "p:1", title: "Topic", url: nil, platformID: "p", platformName: "Platform", rank: 2, publishedAt: nil, extraInfo: nil, topicKey: "topic", previousRank: 8, isRead: false, isFavorite: false)
        let stable = HotNewsItem(id: "p:2", title: "Stable", url: nil, platformID: "p", platformName: "Platform", rank: 5, publishedAt: nil, extraInfo: nil, topicKey: "stable", previousRank: 6, isRead: false, isFavorite: false)
        let topic = HotNewsTopic(id: "topic", title: "Topic", items: [rising])
        let anomaly = HotNewsAnomaly(topicKey: topic.id, title: topic.title, rank: rising.rank, previousRank: rising.previousRank, change: rising.previousRank! - rising.rank, platforms: topic.platforms)

        XCTAssertEqual(anomaly.change, 6)
        XCTAssertTrue(anomaly.isRising)
        XCTAssertEqual(stable.previousRank! - stable.rank, 1)
    }

    func testStructuredAIAnalysisRoundTrip() throws {
        let analysis = StructuredAIAnalysis(overview: "overview", sentimentPositive: 0.2, sentimentNeutral: 0.5, sentimentNegative: 0.3, weakSignals: ["signal"], recommendation: "watch")
        let restored = try JSONDecoder().decode(StructuredAIAnalysis.self, from: JSONEncoder().encode(analysis))
        XCTAssertEqual(restored, analysis)
    }

    func testAnalysisLimitZeroMeansUnlimitedByConfiguration() {
        var settings = AppSettings()
        settings.aiAnalysis.maxNewsForAnalysis = 0
        XCTAssertEqual(settings.aiAnalysis.maxNewsForAnalysis, 0)
    }

    func testNewsNowExtraAcceptsStringAndObjectPayloads() throws {
        let string = try JSONDecoder().decode(NewsNowExtra.self, from: Data("\"1.2k 赞\"".utf8))
        let object = try JSONDecoder().decode(NewsNowExtra.self, from: Data("{\"info\":\"热度\"}".utf8))
        let unsupported = try JSONDecoder().decode(NewsNowExtra.self, from: Data("{\"icon\":{\"url\":\"/icon.png\"}}".utf8))
        XCTAssertEqual(string.info, "1.2k 赞")
        XCTAssertEqual(object.info, "热度")
        XCTAssertNil(unsupported.info)
    }

    func testTopicKeyRemovesPunctuationButPreservesWords() {
        XCTAssertEqual(NewsNowService.topicKey(for: "AI：Swift 5.9!"), "aiswift59")
        XCTAssertEqual(NewsNowService.topicKey(for: "AI Swift 5.9"), "aiswift59")
    }

    func testNewsNowDomainValidationRequiresHTTPSAndExpectedDomain() {
        XCTAssertTrue(NewsNowService.isAllowed(url: URL(string: "https://www.zhihu.com/question/1"), expectedDomain: "zhihu.com"))
        XCTAssertFalse(NewsNowService.isAllowed(url: URL(string: "http://www.zhihu.com/question/1"), expectedDomain: "zhihu.com"))
        XCTAssertFalse(NewsNowService.isAllowed(url: URL(string: "https://example.com/story"), expectedDomain: "zhihu.com"))
        XCTAssertTrue(NewsNowService.isAllowed(url: URL(string: "https://example.com/story"), expectedDomain: nil))
    }

    func testAISettingsPreserveRetryAndFallbackConfiguration() throws {
        var settings = AppSettings()
        settings.ai.retries = 3
        settings.ai.fallbackModels = ["backup-model"]
        let restored = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(restored.ai.retries, 3)
        XCTAssertEqual(restored.ai.fallbackModels, ["backup-model"])
    }

    func testAIPromptTemplateReplacesConfiguredVariables() {
        let template = AIPromptTemplate(content: "[system]\n语言：{language}\n[user]\n新闻：{news_content}")
        let messages = template.messages(values: ["language": "中文", "news_content": "测试新闻"])
        XCTAssertEqual(messages.system, "语言：中文")
        XCTAssertEqual(messages.user, "新闻：测试新闻")
    }

    func testTimelineHandlesNormalAndCrossDayPeriods() {
        let calendar = Calendar(identifier: .gregorian)
        let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 21, hour: 20, minute: 30))!
        let night = calendar.date(from: DateComponents(year: 2026, month: 8, day: 22, hour: 0, minute: 30))!
        let preset = TimelineCatalog.preset(for: "night_owl")
        XCTAssertEqual(preset.action(at: day, calendar: calendar).reportMode, .current)
        XCTAssertEqual(preset.action(at: night, calendar: calendar).reportMode, .daily)
        XCTAssertTrue(preset.action(at: night, calendar: calendar).push)
    }

    func testTimelineExecutionStoreClaimsOnceActions() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "trendradar.timeline.executions")
        let action = TimelineAction(collect: true, analyze: true, push: true, reportMode: .daily, aiMode: .daily, onceAnalyze: true, oncePush: true)
        let date = Date(timeIntervalSince1970: 1_756_000_000)
        let store = TimelineExecutionStore()
        let first = store.claim(presetID: "test", periodID: "period", action: action, at: date, calendar: Calendar(identifier: .gregorian))
        let second = store.claim(presetID: "test", periodID: "period", action: action, at: date, calendar: Calendar(identifier: .gregorian))
        XCTAssertTrue(first.analyze)
        XCTAssertTrue(first.push)
        XCTAssertFalse(second.analyze)
        XCTAssertFalse(second.push)
    }

    func testTimelineExecutionStoreSeparatesExecutionDays() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "trendradar.timeline.executions")
        let action = TimelineAction(collect: true, analyze: true, push: true, reportMode: .daily, aiMode: .daily, onceAnalyze: true, oncePush: true)
        let calendar = Calendar(identifier: .gregorian)
        let firstDay = calendar.date(from: DateComponents(year: 2026, month: 8, day: 21, hour: 20))!
        let secondDay = calendar.date(from: DateComponents(year: 2026, month: 8, day: 22, hour: 20))!
        let store = TimelineExecutionStore()
        _ = store.claim(presetID: "test", periodID: "period", action: action, at: firstDay, calendar: calendar)
        let secondDayResult = store.claim(presetID: "test", periodID: "period", action: action, at: secondDay, calendar: calendar)
        XCTAssertTrue(secondDayResult.analyze)
        XCTAssertTrue(secondDayResult.push)
    }

    func testSettingsRoundTripPreservesRichConfiguration() throws {
        var settings = AppSettings()
        settings.keywords = ["Swift", "AI"]
        settings.schedulePreset = "office_hours"
        settings.rssMaxAgeDays = 3
        settings.customFeeds.append(ConfigFeed(id: "custom", name: "Custom", url: "https://example.com/feed.xml"))
        settings.display.showAIAnalysis = false
        settings.ai.filterMethod = "ai"

        let data = try JSONEncoder().encode(settings)
        let restored = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(restored, settings)
    }

    func testNewSettingsDecodeKeepsDefaultsForLegacyJSON() throws {
        let legacy = Data("{\"keywords\":[\"swift\"],\"enabledFeedIDs\":[\"hn\"],\"refreshInterval\":30}".utf8)
        let settings = try JSONDecoder().decode(AppSettings.self, from: legacy)

        XCTAssertEqual(settings.keywords, ["swift"])
        XCTAssertEqual(settings.refreshInterval, 30)
        XCTAssertEqual(settings.schedulePreset, "night_owl")
        XCTAssertFalse(settings.customFeeds.isEmpty)
        XCTAssertEqual(settings.advanced.rss.timeout, 15)
    }

    func testReportSnapshotPreservesNewsFields() throws {
        let item = NewsItem(
            id: "report-news",
            title: "Snapshot title",
            source: "Test source",
            url: URL(string: "https://example.com/story"),
            publishedAt: Date(timeIntervalSince1970: 100),
            summary: "Snapshot summary",
            isRead: true,
            isFavorite: true
        )
        let snapshot = ReportItemSnapshot(
            orderIndex: 0,
            sectionID: "rss",
            sectionTitle: "RSS",
            item: item
        )

        let restored = try JSONDecoder().decode(ReportItemSnapshot.self, from: JSONEncoder().encode(snapshot))

        XCTAssertEqual(restored, snapshot)
        XCTAssertEqual(restored.title, "Snapshot title")
        XCTAssertTrue(restored.isFavorite)
    }

    func testReportDetailProducesListSummary() {
        let settings = AppSettings()
        let generatedAt = Date(timeIntervalSince1970: 100)
        let detail = ReportDetail(
            id: UUID(),
            title: "今日报告",
            type: .daily,
            trigger: .scheduled,
            generatedAt: generatedAt,
            status: .completed,
            statistics: ReportStatistics(newsCount: 12, sourceCount: 3),
            settingsSnapshot: ReportSettingsSnapshot(settings: settings, reportType: .daily, generatedAt: generatedAt),
            aiAnalysis: ReportAIAnalysis(enabled: true, model: "test-model", language: "Chinese", content: "分析结论", failureMessage: nil),
            sections: [],
            isFavorite: true,
            failureMessage: nil
        )

        XCTAssertEqual(detail.summary.newsCount, 12)
        XCTAssertTrue(detail.summary.hasAIAnalysis)
        XCTAssertTrue(detail.summary.isFavorite)
    }

    func testReportGenerationGroupsLocalNewsAndCalculatesStatistics() {
        var settings = AppSettings()
        settings.keywords = ["Swift"]
        settings.report.displayMode = "keyword"
        let items = [
            NewsItem(id: "swift", title: "Swift on iPhone", source: "Feed A", isFavorite: true),
            NewsItem(id: "other", title: "Other story", source: "Feed B")
        ]
        let request = ReportGenerationRequest(batchID: UUID().uuidString, type: .manual, trigger: .manual, generatedAt: Date(timeIntervalSince1970: 100), settings: settings)
        let report = ReportGenerationService().generate(request: request, items: items)

        XCTAssertEqual(report.statistics.newsCount, 1)
        XCTAssertEqual(report.statistics.sourceCount, 1)
        XCTAssertEqual(report.statistics.favoriteCount, 1)
        XCTAssertEqual(report.sections.count, 1)
        XCTAssertEqual(report.sections[0].items[0].title, "Swift on iPhone")
    }

    func testReportFormatterIncludesHeaderStatisticsAndNews() {
        let settings = AppSettings()
        let item = NewsItem(id: "story", title: "Local story", source: "Feed")
        let snapshot = ReportItemSnapshot(orderIndex: 0, sectionID: "all", sectionTitle: "全部情报", item: item)
        let report = ReportDetail(
            id: UUID(), title: "测试报告", type: .manual, trigger: .manual,
            generatedAt: Date(timeIntervalSince1970: 100),
            status: .completed, statistics: ReportStatistics(newsCount: 1, sourceCount: 1),
            settingsSnapshot: ReportSettingsSnapshot(settings: settings, reportType: .manual, generatedAt: Date(timeIntervalSince1970: 100)),
            aiAnalysis: nil, sections: [ReportSection(id: "all", title: "全部情报", items: [snapshot])],
            isFavorite: false, failureMessage: nil
        )

        let text = ReportFormatter().render(report, format: .plainText)
        XCTAssertTrue(text.contains("测试报告"))
        XCTAssertTrue(text.contains("情报 1 条"))
        XCTAssertTrue(text.contains("Local story"))
    }

    func testReportFormatterIncludesStructuredAIFields() {
        let settings = AppSettings()
        let report = ReportDetail(
            id: UUID(), title: "AI 测试", type: .manual, trigger: .manual,
            generatedAt: Date(timeIntervalSince1970: 100), status: .completed,
            statistics: ReportStatistics(newsCount: 1),
            settingsSnapshot: ReportSettingsSnapshot(settings: settings, reportType: .manual, generatedAt: Date(timeIntervalSince1970: 100)),
            aiAnalysis: ReportAIAnalysis(enabled: true, model: "test", language: "Chinese", content: "overview", failureMessage: nil, sentimentPositive: 0.6, sentimentNeutral: 0.3, sentimentNegative: 0.1, weakSignals: ["signal"], recommendation: "watch"),
            sections: [], isFavorite: false, failureMessage: nil
        )

        let text = ReportFormatter().render(report, format: .plainText)
        XCTAssertTrue(text.contains("正面 60%"))
        XCTAssertTrue(text.contains("弱信号：signal"))
        XCTAssertTrue(text.contains("策略建议：watch"))
    }

    func testKeywordRulesRequireRequiredWordsAndRejectExcludedWords() {
        let rules = KeywordRuleSet(keywords: ["AI, +发布, !广告"], globalExcluded: ["spam"])

        XCTAssertTrue(rules.matches("AI 发布新产品"))
        XCTAssertFalse(rules.matches("AI 新产品"))
        XCTAssertFalse(rules.matches("AI 发布广告"))
        XCTAssertFalse(rules.matches("AI 发布 spam"))
    }

    func testKeywordRulesAllowAllTitlesWhenNoNormalWordsExist() {
        let rules = KeywordRuleSet(keywords: ["+发布"], globalExcluded: [])

        XCTAssertTrue(rules.matches("产品发布"))
        XCTAssertFalse(rules.matches("产品评测"))
    }

    func testKeywordGroupsSupportAliasesAndMaximumCount() {
        let groups = KeywordGroup.parse(["[科技] AI, +发布, !广告, @1"])

        XCTAssertEqual(groups.first?.displayName, "科技")
        XCTAssertEqual(groups.first?.maxCount, 1)
        XCTAssertTrue(groups.first?.matches("AI 发布新产品") == true)
        XCTAssertFalse(groups.first?.matches("AI 发布广告") == true)
    }

    func testReportSummarySearchTextContainsSnapshotFields() {
        let settings = AppSettings()
        let item = NewsItem(id: "search", title: "Swift release", source: "Hacker News", summary: "A new release")
        let snapshot = ReportItemSnapshot(orderIndex: 0, sectionID: "all", sectionTitle: "全部", item: item)
        let report = ReportDetail(
            id: UUID(), title: "本地报告", type: .manual, trigger: .manual,
            generatedAt: Date(), status: .completed, statistics: ReportStatistics(newsCount: 1),
            settingsSnapshot: ReportSettingsSnapshot(settings: settings, reportType: .manual, generatedAt: Date()),
            aiAnalysis: nil, sections: [ReportSection(id: "all", title: "全部", items: [snapshot])],
            isFavorite: false, failureMessage: nil
        )

        XCTAssertTrue(report.summary.searchableText.contains("Hacker News"))
        XCTAssertTrue(report.summary.searchableText.contains("A new release"))
    }

    func testRSSParserReadsRSSItemAndHTMLEntities() throws {
        let data = Data("""
        <?xml version="1.0"?>
        <rss><channel><item>
          <title>AI &amp; Swift</title>
          <link>https://example.com/story</link>
          <description>Summary &lt;today&gt;</description>
          <pubDate>Tue, 01 Jan 2026 12:00:00 +0000</pubDate>
        </item></channel></rss>
        """.utf8)

        let items = try NewsCrawler().parse(data: data, feed: feed)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, "AI & Swift")
        XCTAssertEqual(items[0].summary, "Summary <today>")
        XCTAssertEqual(items[0].url?.absoluteString, "https://example.com/story")
    }

    func testRSSParserReadsAtomLinkAttribute() throws {
        let data = Data("""
        <feed><entry>
          <title>Atom Story</title>
          <link href="https://example.com/atom" />
          <summary>Atom summary</summary>
        </entry></feed>
        """.utf8)

        let items = try NewsCrawler().parse(data: data, feed: feed)

        XCTAssertEqual(items.first?.url?.absoluteString, "https://example.com/atom")
        XCTAssertEqual(items.first?.id, "https://example.com/atom")
    }
}
