import Foundation
import SwiftData

@Model
final class ReportRecord {
    @Attribute(.unique) var id: String
    var title: String
    var reportType: String
    var trigger: String
    var generatedAt: Date
    var status: String
    var newsCount: Int
    var sourceCount: Int
    var unreadCount: Int
    var favoriteCount: Int
    var keywordCount: Int
    var aiEnabled: Bool
    var aiModel: String?
    var aiLanguage: String?
    var aiSummary: String?
    var settingsSnapshotJSON: Data?
    var isFavorite: Bool
    var failureMessage: String?
    var searchableText: String = ""
    var aiSentimentPositive: Double?
    var aiSentimentNeutral: Double?
    var aiSentimentNegative: Double?
    var aiWeakSignalsJSON: Data?
    var aiRecommendation: String?

    init(from report: ReportDetail, encoder: JSONEncoder = .trendRadar) throws {
        id = report.id.uuidString
        title = report.title
        reportType = report.type.rawValue
        trigger = report.trigger.rawValue
        generatedAt = report.generatedAt
        status = report.status.rawValue
        newsCount = report.statistics.newsCount
        sourceCount = report.statistics.sourceCount
        unreadCount = report.statistics.unreadCount
        favoriteCount = report.statistics.favoriteCount
        keywordCount = report.statistics.keywordCount
        aiEnabled = report.aiAnalysis?.enabled ?? false
        aiModel = report.aiAnalysis?.model
        aiLanguage = report.aiAnalysis?.language
        aiSummary = report.aiAnalysis?.content
        settingsSnapshotJSON = try encoder.encode(report.settingsSnapshot)
        isFavorite = report.isFavorite
        failureMessage = report.failureMessage
        searchableText = report.summary.searchableText
        aiSentimentPositive = report.aiAnalysis?.sentimentPositive
        aiSentimentNeutral = report.aiAnalysis?.sentimentNeutral
        aiSentimentNegative = report.aiAnalysis?.sentimentNegative
        aiWeakSignalsJSON = try? encoder.encode(report.aiAnalysis?.weakSignals ?? [])
        aiRecommendation = report.aiAnalysis?.recommendation
    }

    func update(from report: ReportDetail, encoder: JSONEncoder = .trendRadar) throws {
        title = report.title
        reportType = report.type.rawValue
        trigger = report.trigger.rawValue
        generatedAt = report.generatedAt
        status = report.status.rawValue
        newsCount = report.statistics.newsCount
        sourceCount = report.statistics.sourceCount
        unreadCount = report.statistics.unreadCount
        favoriteCount = report.statistics.favoriteCount
        keywordCount = report.statistics.keywordCount
        aiEnabled = report.aiAnalysis?.enabled ?? false
        aiModel = report.aiAnalysis?.model
        aiLanguage = report.aiAnalysis?.language
        aiSummary = report.aiAnalysis?.content
        settingsSnapshotJSON = try encoder.encode(report.settingsSnapshot)
        isFavorite = report.isFavorite
        failureMessage = report.failureMessage
        searchableText = report.summary.searchableText
        aiSentimentPositive = report.aiAnalysis?.sentimentPositive
        aiSentimentNeutral = report.aiAnalysis?.sentimentNeutral
        aiSentimentNegative = report.aiAnalysis?.sentimentNegative
        aiWeakSignalsJSON = try? encoder.encode(report.aiAnalysis?.weakSignals ?? [])
        aiRecommendation = report.aiAnalysis?.recommendation
    }

    func asSummary() -> ReportSummary? {
        guard let uuid = UUID(uuidString: id),
              let type = ReportType(rawValue: reportType),
              let reportStatus = ReportStatus(rawValue: status) else { return nil }
        return ReportSummary(
            id: uuid,
            title: title,
            type: type,
            generatedAt: generatedAt,
            status: reportStatus,
            newsCount: newsCount,
            sourceCount: sourceCount,
            hasAIAnalysis: aiEnabled && !(aiSummary?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true),
            isFavorite: isFavorite,
            searchableText: searchableText
        )
    }

    func asReportDetail(items: [ReportItemRecord], decoder: JSONDecoder = .trendRadar) -> ReportDetail? {
        guard let uuid = UUID(uuidString: id),
              let type = ReportType(rawValue: reportType),
              let reportStatus = ReportStatus(rawValue: status),
              let reportTrigger = ReportTrigger(rawValue: trigger),
              let settingsData = settingsSnapshotJSON,
              let settingsSnapshot = try? decoder.decode(ReportSettingsSnapshot.self, from: settingsData) else { return nil }

        let grouped = Dictionary(grouping: items.filter { $0.reportID == id }, by: \.sectionID)
        let sections = grouped.values.compactMap { records -> ReportSection? in
            guard let first = records.first else { return nil }
            let snapshots = records.sorted { $0.orderIndex < $1.orderIndex }.map(\.asSnapshot)
            return ReportSection(id: first.sectionID, title: first.sectionTitle, items: snapshots)
        }.sorted { left, right in
            let leftIndex = left.items.map(\.orderIndex).min() ?? 0
            let rightIndex = right.items.map(\.orderIndex).min() ?? 0
            return leftIndex < rightIndex
        }

        let analysis = aiEnabled || aiSummary != nil
            ? ReportAIAnalysis(enabled: aiEnabled, model: aiModel, language: aiLanguage ?? "Chinese", content: aiSummary, failureMessage: failureMessage, sentimentPositive: aiSentimentPositive, sentimentNeutral: aiSentimentNeutral, sentimentNegative: aiSentimentNegative, weakSignals: aiWeakSignalsJSON.flatMap { try? decoder.decode([String].self, from: $0) } ?? [], recommendation: aiRecommendation)
            : nil
        return ReportDetail(
            id: uuid,
            title: title,
            type: type,
            trigger: reportTrigger,
            generatedAt: generatedAt,
            status: reportStatus,
            statistics: ReportStatistics(newsCount: newsCount, sourceCount: sourceCount, unreadCount: unreadCount, favoriteCount: favoriteCount, keywordCount: keywordCount),
            settingsSnapshot: settingsSnapshot,
            aiAnalysis: analysis,
            sections: sections,
            isFavorite: isFavorite,
            failureMessage: failureMessage
        )
    }
}

@Model
final class ReportItemRecord {
    @Attribute(.unique) var id: String
    var reportID: String
    var orderIndex: Int
    var sectionID: String
    var sectionTitle: String
    var keyword: String?
    var title: String
    var source: String
    var urlString: String?
    var publishedAt: Date?
    var summary: String?
    var isRead: Bool
    var isFavorite: Bool

    init(reportID: String, snapshot: ReportItemSnapshot) {
        id = "\(reportID):\(snapshot.id)"
        self.reportID = reportID
        orderIndex = snapshot.orderIndex
        sectionID = snapshot.sectionID
        sectionTitle = snapshot.sectionTitle
        keyword = snapshot.keyword
        title = snapshot.title
        source = snapshot.source
        urlString = snapshot.url?.absoluteString
        publishedAt = snapshot.publishedAt
        summary = snapshot.summary
        isRead = snapshot.isRead
        isFavorite = snapshot.isFavorite
    }

    var asSnapshot: ReportItemSnapshot {
        ReportItemSnapshot(
            id: snapshotID,
            orderIndex: orderIndex,
            sectionID: sectionID,
            sectionTitle: sectionTitle,
            keyword: keyword,
            title: title,
            source: source,
            url: urlString.flatMap(URL.init(string:)),
            publishedAt: publishedAt,
            summary: summary,
            isRead: isRead,
            isFavorite: isFavorite
        )
    }

    private var snapshotID: String {
        if let separator = id.lastIndex(of: ":") { return String(id[id.index(after: separator)...]) }
        return id
    }
}

private extension ReportItemSnapshot {
    init(id: String, orderIndex: Int, sectionID: String, sectionTitle: String, keyword: String?, title: String, source: String, url: URL?, publishedAt: Date?, summary: String?, isRead: Bool, isFavorite: Bool) {
        self.id = id
        self.orderIndex = orderIndex
        self.sectionID = sectionID
        self.sectionTitle = sectionTitle
        self.keyword = keyword
        self.title = title
        self.source = source
        self.url = url
        self.publishedAt = publishedAt
        self.summary = summary
        self.isRead = isRead
        self.isFavorite = isFavorite
    }
}

private extension JSONDecoder {
    static var trendRadar: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension JSONEncoder {
    static var trendRadar: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
