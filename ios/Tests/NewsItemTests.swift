import XCTest
@testable import TrendRadar

private actor RetryAttemptCounter {
    private var value = 0

    func increment() -> Int {
        value += 1
        return value
    }
}

final class NewsItemTests: XCTestCase {
    func testLegacyUnreadNewsDefaultsToUnprocessedInbox() throws {
        let data = Data(#"{"id":"legacy-unread","title":"Unread","source":"Feed","isRead":false}"#.utf8)
        let item = try JSONDecoder().decode(NewsItem.self, from: data)
        XCTAssertEqual(item.inboxState, .unprocessed)
    }

    func testLegacyReadNewsDefaultsToArchivedInbox() throws {
        let data = Data(#"{"id":"legacy-read","title":"Read","source":"Feed","isRead":true}"#.utf8)
        let item = try JSONDecoder().decode(NewsItem.self, from: data)
        XCTAssertEqual(item.inboxState, .archived)
    }

    func testNewsInboxStateRoundTrips() throws {
        let original = NewsItem(id: "later", title: "Read later", source: "Feed", inboxState: .readLater)
        let decoded = try JSONDecoder().decode(NewsItem.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(decoded.inboxState, .readLater)
    }
    private let feed = RSSFeed(id: "test", name: "Test Feed", url: URL(string: "https://example.com/rss")!)

    @MainActor
    func testSafeStartupManagerPersistsRecoveryAndClearsIt() throws {
        let suiteName = "SafeStartupManagerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let manager = SafeStartupManager(defaults: defaults)

        manager.markDegraded("cached mode")
        XCTAssertEqual(manager.currentState().status, .degraded)
        XCTAssertEqual(manager.currentState().lastFailureMessage, "cached mode")

        manager.clearRecovery()
        XCTAssertEqual(manager.currentState().status, .normal)
        XCTAssertNil(manager.currentState().lastFailureMessage)
    }

    func testPipelineExecutionReportRoundTripsDiagnostics() throws {
        let requestID = UUID()
        let report = PipelineExecutionReport(
            requestID: requestID,
            trigger: .background,
            startedAt: Date(timeIntervalSince1970: 100),
            finishedAt: Date(timeIntervalSince1970: 103),
            stageResults: [
                PipelineStageResult(name: "collector", success: false, message: "timeout", duration: 3)
            ],
            reportID: nil,
            deliveryStatus: .notAttempted
        )

        let restored = try JSONDecoder().decode(
            PipelineExecutionReport.self,
            from: JSONEncoder().encode(report)
        )

        XCTAssertEqual(restored.requestID, requestID)
        XCTAssertEqual(restored.trigger, .background)
        XCTAssertEqual(restored.stageResults.first?.name, "collector")
        XCTAssertEqual(restored.stageResults.first?.message, "timeout")
        XCTAssertEqual(restored.deliveryStatus, .notAttempted)
        XCTAssertEqual(restored.duration, 3)
    }

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

    func testDefaultPlatformCatalogContainsAtLeastThirtyFiveUniqueSources() {
        let sources = AppSettings.defaultPlatformSources
        let ids = Set(sources.map(\.id))

        XCTAssertGreaterThanOrEqual(sources.count, 35)
        XCTAssertEqual(ids.count, sources.count)
        XCTAssertTrue(ids.contains("zhihu"))
        XCTAssertTrue(ids.contains("github-trending-today"))
    }

    func testHotlistCollectorOutputPreservesPlatformAndRankFields() {
        let item = HotNewsItem(
            id: "zhihu:1",
            title: "热点",
            url: URL(string: "https://www.zhihu.com/question/1"),
            platformID: "zhihu",
            platformName: "知乎",
            rank: 3,
            publishedAt: nil,
            extraInfo: "热度",
            topicKey: "redian",
            previousRank: 6,
            isRead: false,
            isFavorite: true
        )
        let intelligence = IntelligenceItem(
            id: item.id,
            sourceType: .hotlist,
            sourceID: item.platformID,
            sourceName: item.platformName,
            title: item.title,
            url: item.url,
            summary: item.extraInfo,
            topicKey: item.topicKey,
            rank: item.rank,
            previousRank: item.previousRank,
            isFavorite: item.isFavorite
        )

        XCTAssertEqual(intelligence.sourceID, "zhihu")
        XCTAssertEqual(intelligence.rank, 3)
        XCTAssertEqual(intelligence.previousRank, 6)
        XCTAssertTrue(intelligence.isFavorite)
    }

    func testTopicDeduplicatorMergesEquivalentTitlesAndKeepsBestRank() {
        let first = IntelligenceItem(id: "a", sourceType: .hotlist, sourceID: "zhihu", sourceName: "知乎", title: "AI 热榜", topicKey: "ignored", rank: 6)
        let second = IntelligenceItem(id: "b", sourceType: .hotlist, sourceID: "weibo", sourceName: "微博", title: "AI热榜", topicKey: "ignored", rank: 2)

        let topics = TopicDeduplicator().topics(from: [first, second])

        XCTAssertEqual(topics.count, 1)
        XCTAssertEqual(topics.first?.items.count, 2)
        XCTAssertEqual(topics.first?.bestRank, 2)
        XCTAssertEqual(topics.first?.platformCount, 2)
    }

    func testHotNewsTopicDurationUsesFirstSeenTime() {
        let item = HotNewsItem(
            id: "topic:1",
            title: "持续热点",
            url: nil,
            platformID: "zhihu",
            platformName: "知乎",
            rank: 1,
            publishedAt: nil,
            extraInfo: nil,
            topicKey: "topic",
            firstSeenAt: Date(timeIntervalSinceNow: -7_200),
            previousRank: 2,
            isRead: false,
            isFavorite: false
        )
        let topic = HotNewsTopic(id: "topic", title: item.title, items: [item])

        XCTAssertGreaterThanOrEqual(topic.duration ?? 0, 7_200)
    }

    func testFilterEngineSupportsRequiredExcludedAndStandaloneRules() {
        var settings = AppSettings()
        settings.keywords = ["AI", "+发布", "!广告"]
        settings.display.standalonePlatforms = ["zhihu"]
        let engine = FilterEngine(settings: settings)

        XCTAssertTrue(engine.includes(NewsItem(title: "AI 发布新模型", source: "feed")))
        XCTAssertFalse(engine.includes(NewsItem(title: "AI 发布广告", source: "feed")))
        let hotItem = HotNewsItem(id: "zhihu:1", title: "完全不同的标题", url: nil, platformID: "zhihu", platformName: "知乎", rank: 1, publishedAt: nil, extraInfo: nil, topicKey: "other", isRead: false, isFavorite: false)
        XCTAssertTrue(engine.preview(hotItem).isStandalone)
    }

    func testLegacyNewsItemJSONDecodesWithoutArticleBodyFields() throws {
        let data = Data("{\"id\":\"legacy\",\"title\":\"旧文章\",\"source\":\"源\",\"isRead\":false,\"isFavorite\":false}".utf8)
        let item = try JSONDecoder().decode(NewsItem.self, from: data)

        XCTAssertEqual(item.id, "legacy")
        XCTAssertNil(item.body)
        XCTAssertNil(item.author)
    }

    func testRSSParserExtractsAuthorAndArticleBody() throws {
        let xml = """
        <rss><channel><item><title>文章</title><link>https://example.com/a</link><dc:creator>作者</dc:creator><description>摘要</description><content:encoded>正文</content:encoded></item></channel></rss>
        """
        let feed = RSSFeed(id: "test", name: "测试源", url: URL(string: "https://example.com/rss")!)
        let items = try NewsCrawler().parse(data: Data(xml.utf8), feed: feed)

        XCTAssertEqual(items.first?.author, "作者")
        XCTAssertEqual(items.first?.body, "正文")
    }

    func testInsightTimeWindowFiltersDailyItems() {
        let now = Date()
        XCTAssertTrue(InsightTimeWindow.daily.includes(now.addingTimeInterval(-3_600), now: now))
        XCTAssertFalse(InsightTimeWindow.daily.includes(now.addingTimeInterval(-90_000), now: now))
        XCTAssertTrue(InsightTimeWindow.current.includes(now.addingTimeInterval(-900_000), now: now))
    }

    func testInsightCitationKeepsSourceAndURL() {
        let citation = InsightCitation(itemID: "item-1", title: "热点", source: "知乎", url: URL(string: "https://example.com/1"))
        XCTAssertEqual(citation.id, "item-1")
        XCTAssertEqual(citation.source, "知乎")
        XCTAssertNotNil(citation.url)
    }

    func testHotNewsTrendCalculatesRankDirection() {
        let item = HotNewsItem(id: "weibo:1", title: "Trend", url: nil, platformID: "weibo", platformName: "微博", rank: 2, publishedAt: nil, extraInfo: nil, topicKey: "trend", previousRank: 5, isRead: false, isFavorite: false)
        XCTAssertEqual(item.trend, .up)
        XCTAssertEqual(HotNewsItem(id: "x", title: "x", url: nil, platformID: "p", platformName: "P", rank: 5, publishedAt: nil, extraInfo: nil, topicKey: "x", previousRank: 2, isRead: false, isFavorite: false).trend, .down)
        XCTAssertEqual(HotNewsItem(id: "y", title: "y", url: nil, platformID: "p", platformName: "P", rank: 1, publishedAt: nil, extraInfo: nil, topicKey: "y", previousRank: nil, isRead: false, isFavorite: false).trend, .new)
    }

    func testIntelligenceItemRoundTripsAndPreservesSnapshotFields() throws {
        let collectedAt = Date(timeIntervalSince1970: 100)
        let item = IntelligenceItem(
            id: "hotlist:1",
            sourceType: .hotlist,
            sourceID: "zhihu",
            sourceName: "知乎",
            title: "AI 进展",
            url: URL(string: "https://www.zhihu.com/question/1"),
            summary: "摘要",
            topicKey: "aijin zhan".replacingOccurrences(of: " ", with: ""),
            rank: 2,
            previousRank: 5,
            collectedAt: collectedAt,
            isRead: true,
            isFavorite: true
        )

        let restored = try JSONDecoder().decode(IntelligenceItem.self, from: JSONEncoder().encode(item))

        XCTAssertEqual(restored, item)
        XCTAssertEqual(restored.rank, 2)
        XCTAssertEqual(restored.previousRank, 5)
        XCTAssertTrue(restored.isFavorite)
    }

    func testIntelligenceTopicReportsUniquePlatformsAndBestRank() {
        let items = [
            IntelligenceItem(id: "a", sourceType: .hotlist, sourceID: "zhihu", sourceName: "知乎", title: "主题", topicKey: "topic", rank: 4),
            IntelligenceItem(id: "b", sourceType: .hotlist, sourceID: "weibo", sourceName: "微博", title: "主题", topicKey: "topic", rank: 2),
            IntelligenceItem(id: "c", sourceType: .hotlist, sourceID: "weibo", sourceName: "微博", title: "主题", topicKey: "topic", rank: 8)
        ]
        let topic = IntelligenceTopic(id: "topic", topicKey: "topic", title: "主题", items: items, collectedAt: Date())

        XCTAssertEqual(topic.platformNames, ["微博", "知乎"])
        XCTAssertEqual(topic.platformCount, 2)
        XCTAssertEqual(topic.bestRank, 2)
    }

    func testRefreshBatchRoundTripsFailureDetails() throws {
        var batch = RefreshBatch(trigger: .foreground)
        batch.status = .partial
        batch.successfulSourceIDs = ["zhihu"]
        batch.failedSourceIDs = ["weibo"]
        batch.errorMessages = ["weibo": "请求超时"]

        let restored = try JSONDecoder().decode(RefreshBatch.self, from: JSONEncoder().encode(batch))

        XCTAssertEqual(restored, batch)
        XCTAssertEqual(restored.status, .partial)
        XCTAssertEqual(restored.errorMessages["weibo"], "请求超时")
    }

    func testSourceDataCompletenessMarksCachedDataUsable() {
        let source = SourceDataCompleteness(
            sourceID: "zhihu",
            sourceName: "知乎",
            status: .cached,
            itemCount: 10,
            collectedAt: Date(),
            errorMessage: "本次刷新失败"
        )

        XCTAssertTrue(source.hasUsableData)
    }

    func testTrendStateUsesOnlyObservedRankSnapshots() {
        let start = Date(timeIntervalSince1970: 1_000)
        let rising = [
            RankSnapshot(sourceID: "zhihu", sourceName: "知乎", rank: 9, capturedAt: start),
            RankSnapshot(sourceID: "zhihu", sourceName: "知乎", rank: 3, capturedAt: start.addingTimeInterval(600))
        ]
        XCTAssertEqual(TrendStateClassifier.classify(snapshots: rising, firstSeenAt: start, lastSeenAt: start.addingTimeInterval(600)), .rising)
        XCTAssertEqual(TrendStateClassifier.classify(snapshots: Array(rising.reversed()), firstSeenAt: start, lastSeenAt: start.addingTimeInterval(600)), .rising)
        XCTAssertEqual(TrendStateClassifier.classify(snapshots: [rising[0]], firstSeenAt: start, lastSeenAt: start), .new)
    }

    func testTrendTopicCountsUniqueSourcesAndPlatforms() {
        let now = Date()
        let items = [
            IntelligenceItem(id: "hot", sourceType: .hotlist, sourceID: "weibo", sourceName: "微博", title: "主题", topicKey: "topic", rank: 2),
            IntelligenceItem(id: "rss", sourceType: .rss, sourceID: "feed", sourceName: "订阅源", title: "主题", topicKey: "topic")
        ]
        let topic = TrendTopic(id: "topic", normalizedTitle: "主题", title: "主题", items: items, firstSeenAt: now, lastSeenAt: now)

        XCTAssertEqual(topic.platformCount, 1)
        XCTAssertEqual(topic.sourceCount, 2)
        XCTAssertEqual(topic.bestRank, 2)
        XCTAssertEqual(topic.state, .new)
    }

    func testRadarFiltersUseObservedStateAndFavorites() {
        let now = Date()
        let rising = HotNewsItem(id: "rising", title: "上升主题", url: nil, platformID: "weibo", platformName: "微博", rank: 2, publishedAt: nil, extraInfo: nil, topicKey: "rising", firstSeenAt: now.addingTimeInterval(-900), previousRank: 8, isRead: false, isFavorite: false)
        let followed = HotNewsItem(id: "followed", title: "关注主题", url: nil, platformID: "zhihu", platformName: "知乎", rank: 5, publishedAt: nil, extraInfo: nil, topicKey: "followed", firstSeenAt: now.addingTimeInterval(-25_000), previousRank: 5, isRead: false, isFavorite: true)

        XCTAssertTrue(RadarFilter.rising.includes(HotNewsTopic(id: "rising", title: rising.title, items: [rising]), now: now))
        XCTAssertTrue(RadarFilter.sustained.includes(HotNewsTopic(id: "followed", title: followed.title, items: [followed]), now: now))
        XCTAssertTrue(RadarFilter.following.includes(HotNewsTopic(id: "followed", title: followed.title, items: [followed]), now: now))
        XCTAssertFalse(RadarFilter.new.includes(HotNewsTopic(id: "rising", title: rising.title, items: [rising]), now: now))
    }

    func testTodayDigestSelectsOnlyObservedAndFollowedTopics() {
        let rising = HotNewsItem(id: "rising", title: "升温", url: nil, platformID: "weibo", platformName: "微博", rank: 1, publishedAt: nil, extraInfo: nil, topicKey: "rising", previousRank: 6, isRead: false, isFavorite: false)
        let followed = HotNewsItem(id: "followed", title: "关注", url: nil, platformID: "zhihu", platformName: "知乎", rank: 2, publishedAt: nil, extraInfo: nil, topicKey: "followed", previousRank: 2, isRead: false, isFavorite: true)
        let news = [NewsItem(id: "one", title: "情报", source: "Feed"), NewsItem(id: "two", title: "已读", source: "Feed", isRead: true)]
        let digest = TodayDigestBuilder.build(news: news, topics: [HotNewsTopic(id: "rising", title: rising.title, items: [rising]), HotNewsTopic(id: "followed", title: followed.title, items: [followed])], failureCount: 1)

        XCTAssertEqual(digest.topTopics.count, 2)
        XCTAssertEqual(digest.risingTopics.map(\.id), ["rising"])
        XCTAssertEqual(digest.followedTopics.map(\.id), ["followed"])
        XCTAssertEqual(digest.unreadCount, 1)
        XCTAssertTrue(digest.briefing.contains("1 个来源"))
    }

    func testSourceHealthStorePersistsFailureAndRecovery() async throws {
        let suiteName = "SourceHealthStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SourceHealthStore(defaults: defaults)

        await store.record(sourceID: "weibo", sourceName: "微博", error: "超时", cacheAvailable: true)
        var values = await store.load()
        var health = try XCTUnwrap(values.first)
        XCTAssertEqual(health.consecutiveFailures, 1)
        XCTAssertTrue(health.cacheAvailable)

        await store.record(sourceID: "weibo", sourceName: "微博", error: nil, cacheAvailable: true)
        values = await store.load()
        health = try XCTUnwrap(values.first)
        XCTAssertEqual(health.consecutiveFailures, 0)
        XCTAssertNil(health.lastError)
        XCTAssertNotNil(health.lastSuccessAt)
    }

    func testArchiveResourceUsesStableNamespacedIdentifier() throws {
        let resource = ArchiveResource(resourceID: "item-1", kind: .rss, title: "文章", source: "RSS")
        let restored = try JSONDecoder().decode(ArchiveResource.self, from: JSONEncoder().encode(resource))

        XCTAssertEqual(resource.id, "rss:item-1")
        XCTAssertEqual(restored, resource)
        XCTAssertTrue(restored.isFavorite)
    }

    func testArchiveRecordPreservesResourceMetadata() {
        let resource = ArchiveResource(resourceID: "report-1", kind: .report, title: "日报", source: "Insight", summary: "摘要", isFavorite: true)
        let record = ArchiveRecord(resource: resource)

        XCTAssertEqual(record.id, "report:report-1")
        XCTAssertEqual(record.asResource, resource)
    }

    func testArchiveResourcesNormalizeNewsTrendAndReport() {
        let date = Date(timeIntervalSince1970: 100)
        let news = ArchiveResource(news: NewsItem(id: "news-1", title: "Swift update", source: "Feed", url: URL(string: "https://example.com/news"), publishedAt: date, summary: "Summary", isFavorite: true))
        let hotItem = HotNewsItem(id: "hot-1", title: "AI trend", url: URL(string: "https://example.com/hot"), platformID: "weibo", platformName: "微博", rank: 2, publishedAt: date, extraInfo: nil, topicKey: "ai", isRead: false, isFavorite: true)
        let trend = ArchiveResource(topic: HotNewsTopic(id: "ai", title: "AI trend", items: [hotItem]))
        let report = ArchiveResource(report: ReportSummary(id: UUID(), title: "日报", type: .daily, generatedAt: date, status: .completed, newsCount: 3, sourceCount: 2, hasAIAnalysis: false, isFavorite: true))

        XCTAssertEqual(news.id, "rss:news-1")
        XCTAssertEqual(news.capturedAt, date)
        XCTAssertTrue(news.searchableText.contains("Summary"))
        XCTAssertEqual(trend.id, "hotlist:ai")
        XCTAssertEqual(trend.summary, "最佳排名 #2 · 1 个平台")
        XCTAssertEqual(report.kind, .report)
        XCTAssertEqual(report.summary, "3 条情报 · 2 个来源")
    }

    func testArchiveShareTextIncludesAvailableEvidence() {
        let resource = ArchiveResource(resourceID: "item", kind: .rss, title: "Title", source: "Source", url: URL(string: "https://example.com"), summary: "Summary")

        XCTAssertEqual(resource.shareText, "Title\nSource\nSummary\nhttps://example.com")
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

    func testPlatformAPIURLMigratesBlockedPublicEndpoint() {
        XCTAssertEqual(
            AppSettings.effectivePlatformAPIURL(AppSettings.legacyPlatformAPIURL),
            AppSettings.defaultPlatformAPIURL
        )
        XCTAssertEqual(
            AppSettings.effectivePlatformAPIURL(""),
            AppSettings.defaultPlatformAPIURL
        )
        XCTAssertEqual(
            AppSettings.effectivePlatformAPIURL("https://example.com/api"),
            "https://example.com/api"
        )
    }

    func testNewsNowDomainValidationRequiresHTTPSAndExpectedDomain() {
        XCTAssertTrue(NewsNowService.isAllowed(url: URL(string: "https://www.zhihu.com/question/1"), expectedDomain: "zhihu.com"))
        XCTAssertFalse(NewsNowService.isAllowed(url: URL(string: "http://www.zhihu.com/question/1"), expectedDomain: "zhihu.com"))
        XCTAssertFalse(NewsNowService.isAllowed(url: URL(string: "https://example.com/story"), expectedDomain: "zhihu.com"))
        XCTAssertTrue(NewsNowService.isAllowed(url: URL(string: "https://example.com/story"), expectedDomain: nil))
    }

    func testNetworkFetchErrorRetryability() {
        XCTAssertTrue(NetworkFetchError.httpStatus(429).isRetryable)
        XCTAssertTrue(NetworkFetchError.httpStatus(503).isRetryable)
        XCTAssertFalse(NetworkFetchError.httpStatus(404).isRetryable)
        XCTAssertFalse(NetworkFetchError.transport(URLError(.cancelled)).isRetryable)
    }

    func testNetworkRetrySucceedsAfterTransientFailures() async throws {
        let counter = RetryAttemptCounter()
        let result = try await NetworkRetrying.perform(attempts: 3) {
            if await counter.increment() < 3 {
                throw NetworkFetchError.transport(URLError(.timedOut))
            }
            return "ok"
        }
        XCTAssertEqual(result, "ok")
        let attempts = await counter.increment()
        XCTAssertEqual(attempts, 4)
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

    func testAIFilterMatchDecodesSnakeCaseAndRejectsInvalidScore() throws {
        let data = Data("[{\"id\":1,\"tag_id\":2,\"score\":0.9},{\"id\":2,\"tag_id\":1,\"score\":1.2}]".utf8)
        let matches = try JSONDecoder().decode([AIFilterMatch].self, from: data)
        XCTAssertEqual(matches[0].tagID, 2)
        XCTAssertEqual(matches[0].score, 0.9)
        XCTAssertFalse(matches[1].score >= 0 && matches[1].score <= 1)
    }

    func testInterestTagsRoundTripAndUpdateDecoding() throws {
        var settings = AppSettings()
        settings.ai.interestTags = [AIInterestTag(id: 1, tag: "人工智能", description: "模型与应用")]
        let restored = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(restored.ai.interestTags, settings.ai.interestTags)
        let update = try JSONDecoder().decode(AIInterestTagUpdate.self, from: Data("{\"keep\":[],\"add\":[{\"tag\":\"芯片\",\"description\":\"处理器\"}],\"remove\":[],\"change_ratio\":0.2}".utf8))
        XCTAssertEqual(update.changeRatio, 0.2)
        XCTAssertEqual(update.add.first?.tag, "芯片")
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

    func testReportMarkdownRendererIncludesLinksSummariesAndFooter() {
        let settings = AppSettings()
        let item = NewsItem(id: "linked", title: "Linked story", source: "Feed", url: URL(string: "https://example.com/story"), summary: "A short summary")
        let report = ReportGenerationService().generate(
            request: ReportGenerationRequest(batchID: "presentation-markdown", type: .manual, trigger: .manual, generatedAt: Date(timeIntervalSince1970: 100), settings: settings),
            items: [item]
        )
        let markdown = ReportMarkdownRenderer().render(report)
        XCTAssertTrue(markdown.contains("[Linked story](https://example.com/story)"))
        XCTAssertTrue(markdown.contains("> A short summary"))
        XCTAssertTrue(markdown.contains("📊 报告概览"))
        XCTAssertTrue(markdown.contains("报告 ID："))
    }

    func testReportGenerationPersistsTopicStatsAndCompletenessMetadata() {
        var settings = AppSettings()
        settings.keywords = ["[人工智能] AI"]
        settings.timezone = "Asia/Shanghai"
        let diagnostics = ReportDiagnostics(
            failures: [ReportSourceFailure(sourceType: .rss, source: "示例源", message: "超时")],
            collectedAt: Date(timeIntervalSince1970: 100)
        )
        let report = ReportGenerationService().generate(
            request: ReportGenerationRequest(
                batchID: "report-metadata",
                type: .manual,
                trigger: .manual,
                generatedAt: Date(timeIntervalSince1970: 100),
                settings: settings,
                diagnostics: diagnostics
            ),
            items: [
                NewsItem(id: "ai-1", title: "AI 新模型发布", source: "Feed A"),
                NewsItem(id: "other-1", title: "其他内容", source: "Feed B")
            ]
        )

        XCTAssertEqual(report.metadata.schemaVersion, 1)
        XCTAssertEqual(report.metadata.collectedItemCount, 2)
        XCTAssertEqual(report.metadata.matchedItemCount, 1)
        XCTAssertTrue(report.metadata.isPartial)
        XCTAssertEqual(report.topicStats.first?.name, "人工智能")
        XCTAssertEqual(report.topicStats.first?.count, 1)
    }

    func testReportOutputsShareTopicStatsAndSchemaMetadata() throws {
        var settings = AppSettings()
        settings.keywords = ["AI"]
        let report = ReportGenerationService().generate(
            request: ReportGenerationRequest(batchID: "shared-report-output", type: .manual, trigger: .manual, generatedAt: Date(timeIntervalSince1970: 100), settings: settings),
            items: [NewsItem(id: "ai-output", title: "AI 行业动态", source: "Feed")]
        )

        let markdown = ReportMarkdownRenderer().render(report)
        let html = ReportHTMLFormatter().render(report)
        let payload = try WebhookPayloadRenderer().render(report: report, template: "", batchContent: markdown, batchIndex: 1, batchTotal: 1)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: payload) as? [String: Any])

        XCTAssertTrue(markdown.contains("热点词汇统计"))
        XCTAssertTrue(markdown.contains("协议 v1"))
        XCTAssertTrue(html.contains("热点词汇统计"))
        XCTAssertTrue(html.contains("协议 v1"))
        XCTAssertEqual(json["schema_version"] as? Int, 1)
        XCTAssertEqual(json["data_complete"] as? Bool, true)
    }

    func testReportOutputsShareEvidenceSummary() throws {
        var settings = AppSettings()
        settings.keywords = ["AI"]
        let generatedAt = Date(timeIntervalSince1970: 10_000)
        let diagnostics = ReportDiagnostics(
            failures: [ReportSourceFailure(sourceType: .rss, source: "Feed B", message: "timeout")],
            collectedAt: generatedAt
        )
        let report = ReportGenerationService().generate(
            request: ReportGenerationRequest(batchID: "evidence", type: .manual, trigger: .manual, generatedAt: generatedAt, settings: settings, windowStart: generatedAt.addingTimeInterval(-3_600), diagnostics: diagnostics),
            items: [NewsItem(id: "evidence-1", title: "AI release", source: "Feed A")]
        )

        let evidence = ReportPresentationModel(report: report).evidence
        let markdown = ReportMarkdownRenderer().render(report)
        let html = ReportHTMLFormatter().render(report)
        let payload = try WebhookPayloadRenderer().render(report: report, template: "", batchContent: markdown, batchIndex: 1, batchTotal: 1)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: payload) as? [String: Any])

        XCTAssertEqual(evidence.sampleCount, 1)
        XCTAssertEqual(evidence.failedSourceCount, 1)
        XCTAssertEqual(evidence.citedItemCount, 1)
        XCTAssertEqual(evidence.generationMethod, "本地规则")
        XCTAssertTrue(markdown.contains("证据：1 条引用 · 1 个失败来源 · 本地规则"))
        XCTAssertTrue(html.contains("证据与范围"))
        XCTAssertTrue(html.contains("引用 1 条 · 失败来源 1 个 · 本地规则"))
        XCTAssertEqual(json["sample_count"] as? Int, 1)
        XCTAssertEqual(json["failed_source_count"] as? Int, 1)
        XCTAssertEqual(json["citation_count"] as? Int, 1)
        XCTAssertEqual(json["generation_method"] as? String, "本地规则")
    }

    func testReportMarkdownRendererHonorsConfiguredRegionOrder() {
        var settings = AppSettings()
        settings.display.regionOrder = ["rss", "hotlist", "ai_analysis"]
        let generatedAt = Date(timeIntervalSince1970: 100)
        let rss = NewsItem(id: "rss-order", title: "RSS order", source: "Feed", publishedAt: generatedAt)
        let hot = HotNewsItem(id: "hot-order", title: "Hot order", url: URL(string: "https://example.com/hot"), platformID: "weibo", platformName: "微博", rank: 1, publishedAt: generatedAt, extraInfo: nil, topicKey: "hot", isRead: false, isFavorite: false)
        let report = ReportGenerationService().generate(
            request: ReportGenerationRequest(batchID: "presentation-order", type: .manual, trigger: .manual, generatedAt: generatedAt, settings: settings),
            items: [rss], hotlistItems: [hot]
        )
        let markdown = ReportMarkdownRenderer().render(report)
        XCTAssertLessThan(markdown.range(of: "## 全部情报")!.lowerBound, markdown.range(of: "## 热榜")!.lowerBound)
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

    func testHTMLReportExportEscapesContentAndKeepsLinks() {
        let settings = AppSettings()
        let item = NewsItem(id: "html-item", title: "A <B> & C", source: "Example", url: URL(string: "https://example.com/?a=1&b=2"))
        let request = ReportGenerationRequest(batchID: "html-export", type: .manual, trigger: .manual, generatedAt: Date(timeIntervalSince1970: 100), settings: settings)
        let report = ReportGenerationService().generate(request: request, items: [item])
        let html = ReportHTMLFormatter().render(report)

        XCTAssertTrue(html.contains("A &lt;B&gt; &amp; C"))
        XCTAssertTrue(html.contains("https://example.com/?a=1&amp;b=2"))
        XCTAssertTrue(html.contains("<meta name=\"viewport\""))
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

    func testReportGenerationCombinesHotlistAndRSSAndCountsSources() {
        var settings = AppSettings()
        settings.keywords = []
        let generatedAt = Date(timeIntervalSince1970: 10_000)
        let rss = NewsItem(id: "rss-1", title: "RSS item", source: "Feed", publishedAt: generatedAt)
        let hot = HotNewsItem(id: "hot-1", title: "Hot item", url: nil, platformID: "weibo", platformName: "微博", rank: 2, publishedAt: generatedAt, extraInfo: nil, topicKey: "hot", isRead: false, isFavorite: false)
        let request = ReportGenerationRequest(batchID: "sources", type: .current, trigger: .manual, generatedAt: generatedAt, settings: settings)

        let report = ReportGenerationService().generate(request: request, items: [rss], hotlistItems: [hot])

        XCTAssertEqual(report.statistics.hotlistCount, 1)
        XCTAssertEqual(report.statistics.rssCount, 1)
        XCTAssertEqual(report.statistics.hotlistPlatformCount, 1)
        XCTAssertEqual(report.statistics.rssSourceCount, 1)
        XCTAssertEqual(report.statistics.sourceCount, 2)
    }

    func testDailyAndIncrementalReportsUseStrictWindows() {
        var settings = AppSettings()
        settings.timezone = "UTC"
        settings.refreshInterval = 60
        let now = Date(timeIntervalSince1970: 86_400 + 3_600)
        let old = NewsItem(id: "old", title: "Old", source: "Feed", publishedAt: now.addingTimeInterval(-90_000))
        let today = NewsItem(id: "today", title: "Today", source: "Feed", publishedAt: now.addingTimeInterval(-1_800))
        let daily = ReportGenerationService().generate(request: ReportGenerationRequest(batchID: "daily-window", type: .daily, trigger: .manual, generatedAt: now, settings: settings), items: [old, today])
        let incremental = ReportGenerationService().generate(request: ReportGenerationRequest(batchID: "incremental-window", type: .incremental, trigger: .manual, generatedAt: now, settings: settings), items: [old, today])

        XCTAssertEqual(daily.statistics.newsCount, 1)
        XCTAssertEqual(incremental.statistics.newsCount, 1)
        XCTAssertEqual(daily.sections.flatMap(\.items).first?.id, "today")
        XCTAssertEqual(incremental.sections.flatMap(\.items).first?.id, "today")
    }

    func testManualReportBatchIDsAllowRepeatedGeneration() {
        let settings = AppSettings()
        let first = ReportGenerationService().generate(request: ReportGenerationRequest(batchID: "manual-1", type: .manual, trigger: .manual, generatedAt: Date(), settings: settings), items: [NewsItem(id: "one", title: "One", source: "Feed")])
        let second = ReportGenerationService().generate(request: ReportGenerationRequest(batchID: "manual-2", type: .manual, trigger: .manual, generatedAt: Date(), settings: settings), items: [NewsItem(id: "one", title: "One", source: "Feed")])

        XCTAssertNotEqual(first.id, second.id)
    }

    func testWebhookPayloadDefaultFormatContainsReportMetadata() throws {
        let settings = AppSettings()
        let report = ReportGenerationService().generate(
            request: ReportGenerationRequest(batchID: "webhook-default", type: .manual, trigger: .manual, generatedAt: Date(timeIntervalSince1970: 100), settings: settings),
            items: [NewsItem(id: "item", title: "Webhook report", source: "Feed")]
        )
        let data = try WebhookPayloadRenderer().render(report: report, template: "", batchContent: "body", batchIndex: 1, batchTotal: 1)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(object?["title"] as? String, report.title)
        XCTAssertEqual(object?["content"] as? String, "body")
        XCTAssertEqual(object?["report_type"] as? String, "manual")
    }

    func testWebhookPayloadTemplateEscapesQuotesAndNewlines() throws {
        let settings = AppSettings()
        let report = ReportGenerationService().generate(
            request: ReportGenerationRequest(batchID: "webhook-template", type: .manual, trigger: .manual, generatedAt: Date(), settings: settings),
            items: [NewsItem(id: "item", title: "Webhook report", source: "Feed")]
        )
        let data = try WebhookPayloadRenderer().render(report: report, template: "{\"content\":\"{content}\",\"title\":\"{title}\"}", batchContent: "quote: \"\nnext", batchIndex: 1, batchTotal: 1)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(object?["content"] as? String, "quote: \"\nnext")
        XCTAssertEqual(object?["title"] as? String, report.title)
    }

    func testLegacyWebhookDeliveryRecordsRemainDecodable() throws {
        let data = Data("""
        {
          "id": "legacy",
          "createdAt": 0,
          "reportID": "report",
          "status": 200,
          "success": true,
          "attempts": 1,
          "message": "sent"
        }
        """.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let record = try decoder.decode(WebhookDeliveryRecord.self, from: data)

        XCTAssertEqual(record.id, "legacy")
        XCTAssertNil(record.channel)
        XCTAssertNil(record.batchIndex)
        XCTAssertNil(record.responseSummary)
    }

    func testReportDeliverySkipsWhenNotificationsAreDisabled() async {
        var settings = AppSettings()
        settings.notification.enabled = false
        let report = ReportGenerationService().generate(
            request: ReportGenerationRequest(batchID: "delivery-skipped", type: .manual, trigger: .manual, generatedAt: Date(), settings: settings),
            items: [NewsItem(id: "item", title: "Report", source: "Feed")]
        )

        let result = await ReportDeliveryService().deliver(report: report, settings: settings)

        XCTAssertTrue(result.succeeded)
        XCTAssertNil(result.failureMessage)
    }

    func testBackgroundRefreshRejectsLiveContainerHosts() {
        XCTAssertFalse(BackgroundRefreshService.isSupportedHost(
            processName: "LiveProcess",
            bundlePath: "/private/var/mobile/Containers/Data/Application/ABC/Documents/Applications/com.trendradar.mobile.app"
        ))
        XCTAssertFalse(BackgroundRefreshService.isSupportedHost(
            processName: "TrendRadar",
            bundlePath: "/private/var/mobile/Containers/Data/Application/ABC/Documents/Applications/com.trendradar.mobile.app"
        ))
    }

    func testBackgroundRefreshAcceptsNormalInstalledApp() {
        XCTAssertTrue(BackgroundRefreshService.isSupportedHost(
            processName: "TrendRadar",
            bundlePath: "/private/var/containers/Bundle/Application/ABC/TrendRadar.app"
        ))
    }

    func testWebhookPayloadRejectsInvalidJSONTemplate() {
        let settings = AppSettings()
        let report = ReportGenerationService().generate(
            request: ReportGenerationRequest(batchID: "webhook-invalid", type: .manual, trigger: .manual, generatedAt: Date(), settings: settings),
            items: [NewsItem(id: "item", title: "Webhook report", source: "Feed")]
        )

        XCTAssertThrowsError(try WebhookPayloadRenderer().render(report: report, template: "{not-json}", batchContent: "body", batchIndex: 1, batchTotal: 1))
    }

    func testDisplayThemeAndTypographyRoundTrip() throws {
        var settings = AppSettings()
        settings.display.appearance = .light
        settings.display.fontStyle = .serif
        settings.display.fontScale = 1.2
        settings.display.uiScale = 1.1
        settings.display.cardSpacing = 20

        let restored = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))

        XCTAssertEqual(restored.display.appearance, .light)
        XCTAssertEqual(restored.display.fontStyle, .serif)
        XCTAssertEqual(restored.display.fontScale, 1.2)
        XCTAssertEqual(restored.display.uiScale, 1.1)
        XCTAssertEqual(restored.display.cardSpacing, 20)
    }

    func testLegacyDisplaySettingsUseVisualDefaults() throws {
        let restored = try JSONDecoder().decode(DisplaySettings.self, from: Data("{}".utf8))

        XCTAssertEqual(restored.appearance, .dark)
        XCTAssertEqual(restored.fontStyle, .system)
        XCTAssertEqual(restored.fontScale, 1.0)
    }
}
