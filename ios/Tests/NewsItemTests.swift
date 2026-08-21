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
