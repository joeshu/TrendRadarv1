import Foundation

struct TodayDigest: Sendable {
    let topTopics: [HotNewsTopic]
    let risingTopics: [HotNewsTopic]
    let followedTopics: [HotNewsTopic]
    let newsCount: Int
    let unreadCount: Int
    let failureCount: Int

    var briefing: String {
        guard newsCount > 0 || !topTopics.isEmpty else { return "本机暂无可用情报。连接网络刷新，或继续浏览已有归档。" }
        var parts = ["本机已汇总 \(newsCount) 条订阅情报和 \(topTopics.count) 个重点趋势。"]
        if !risingTopics.isEmpty { parts.append("其中 \(risingTopics.count) 个主题正在升温。") }
        if failureCount > 0 { parts.append("\(failureCount) 个来源本轮异常，缓存内容仍可浏览。") }
        return parts.joined()
    }
}

enum TodayDigestBuilder {
    static func build(news: [NewsItem], topics: [HotNewsTopic], failureCount: Int) -> TodayDigest {
        TodayDigest(
            topTopics: Array(topics.prefix(3)),
            risingTopics: Array(topics.filter { $0.strongestTrend == .up }.prefix(3)),
            followedTopics: Array(topics.filter { $0.items.contains(where: \.isFavorite) }.prefix(3)),
            newsCount: news.count,
            unreadCount: news.filter { !$0.isRead }.count,
            failureCount: failureCount
        )
    }
}
