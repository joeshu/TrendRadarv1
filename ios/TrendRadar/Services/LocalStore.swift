import Foundation
import SwiftData

actor LocalStore {
    private let container: ModelContainer?
    private let legacyFileURL: URL

    init() {
        container = try? ModelContainer(for: NewsRecord.self, ReportRecord.self, ReportItemRecord.self, HotNewsRecord.self, HotNewsTrendRecord.self)
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        legacyFileURL = directory.appendingPathComponent("news.json")
    }

    func load() -> [NewsItem] {
        guard let container else { return loadLegacyJSON() }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<NewsRecord>(sortBy: [SortDescriptor(\NewsRecord.publishedAt, order: .reverse)])
        guard var records = try? context.fetch(descriptor) else { return [] }
        if records.isEmpty {
            migrateLegacyJSON(into: context)
            records = (try? context.fetch(descriptor)) ?? []
        }
        return records.map { $0.asNewsItem() }
    }

    func save(_ items: [NewsItem]) {
        guard let container else {
            saveLegacyJSON(items)
            return
        }
        let context = ModelContext(container)
        let existing = (try? context.fetch(FetchDescriptor<NewsRecord>())) ?? []
        let recordsByID = existing.reduce(into: [String: NewsRecord]()) { $0[$1.id] = $1 }
        for item in items {
            if let record = recordsByID[item.id] {
                update(record, from: item)
            } else {
                context.insert(NewsRecord(from: item))
            }
        }
        try? context.save()
    }

    func clearAll() throws {
        guard let container else {
            try? FileManager.default.removeItem(at: legacyFileURL)
            return
        }
        let context = ModelContext(container)
        for record in try context.fetch(FetchDescriptor<NewsRecord>()) { context.delete(record) }
        for record in try context.fetch(FetchDescriptor<ReportItemRecord>()) { context.delete(record) }
        for record in try context.fetch(FetchDescriptor<ReportRecord>()) { context.delete(record) }
        for record in try context.fetch(FetchDescriptor<HotNewsTrendRecord>()) { context.delete(record) }
        for record in try context.fetch(FetchDescriptor<HotNewsRecord>()) { context.delete(record) }
        try context.save()
    }

    func loadReportSummaries() -> [ReportSummary] {
        guard let container else { return [] }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ReportRecord>(sortBy: [SortDescriptor(\ReportRecord.generatedAt, order: .reverse)])
        return (try? context.fetch(descriptor).compactMap { $0.asSummary() }) ?? []
    }

    func loadReport(id: UUID) -> ReportDetail? {
        guard let container else { return nil }
        let context = ModelContext(container)
        let reportID = id.uuidString
        let reportDescriptor = FetchDescriptor<ReportRecord>(
            predicate: #Predicate { $0.id == reportID }
        )
        guard let record = try? context.fetch(reportDescriptor).first else { return nil }

        let itemDescriptor = FetchDescriptor<ReportItemRecord>(
            predicate: #Predicate { $0.reportID == reportID },
            sortBy: [SortDescriptor(\ReportItemRecord.orderIndex)]
        )
        let items = (try? context.fetch(itemDescriptor)) ?? []
        return record.asReportDetail(items: items)
    }

    func save(_ report: ReportDetail) throws {
        guard let container else { throw LocalStoreError.unavailable }
        let context = ModelContext(container)
        let reportID = report.id.uuidString
        let descriptor = FetchDescriptor<ReportRecord>(predicate: #Predicate { $0.id == reportID })

        if let record = try context.fetch(descriptor).first {
            try record.update(from: report)
            let itemDescriptor = FetchDescriptor<ReportItemRecord>(predicate: #Predicate { $0.reportID == reportID })
            for item in try context.fetch(itemDescriptor) {
                context.delete(item)
            }
        } else {
            context.insert(try ReportRecord(from: report))
        }

        for section in report.sections {
            for snapshot in section.items {
                context.insert(ReportItemRecord(reportID: reportID, snapshot: snapshot))
            }
        }
        try context.save()
    }

    func toggleReportFavorite(id: UUID) throws {
        guard let container else { throw LocalStoreError.unavailable }
        let context = ModelContext(container)
        let reportID = id.uuidString
        let descriptor = FetchDescriptor<ReportRecord>(predicate: #Predicate { $0.id == reportID })
        guard let record = try context.fetch(descriptor).first else { return }
        record.isFavorite.toggle()
        try context.save()
    }

    func deleteReport(id: UUID) throws {
        guard let container else { throw LocalStoreError.unavailable }
        let context = ModelContext(container)
        let reportID = id.uuidString
        let reportDescriptor = FetchDescriptor<ReportRecord>(predicate: #Predicate { $0.id == reportID })
        let itemDescriptor = FetchDescriptor<ReportItemRecord>(predicate: #Predicate { $0.reportID == reportID })
        for item in try context.fetch(itemDescriptor) {
            context.delete(item)
        }
        for report in try context.fetch(reportDescriptor) {
            context.delete(report)
        }
        try context.save()
    }

    func applyReportRetention(days: Int, now: Date = Date()) throws {
        guard days > 0, let container else { return }
        let context = ModelContext(container)
        let cutoff = now.addingTimeInterval(-Double(days) * 86_400)
        let descriptor = FetchDescriptor<ReportRecord>(predicate: #Predicate { !$0.isFavorite && $0.generatedAt < cutoff })
        let reports = try context.fetch(descriptor)
        let reportIDs = Set(reports.map(\.id))
        let itemDescriptor = FetchDescriptor<ReportItemRecord>()
        for item in try context.fetch(itemDescriptor) where reportIDs.contains(item.reportID) {
            context.delete(item)
        }
        for report in reports {
            context.delete(report)
        }
        try context.save()
    }

    func saveHotNews(_ items: [HotNewsItem], replacingPlatformIDs: Set<String> = [], seenAt: Date = Date()) throws {
        guard let container else { throw LocalStoreError.unavailable }
        let context = ModelContext(container)
        let existing = try context.fetch(FetchDescriptor<HotNewsRecord>())
        let recordsByID = existing.reduce(into: [String: HotNewsRecord]()) { $0[$1.id] = $1 }
        for record in existing where replacingPlatformIDs.contains(record.platformID) {
            context.delete(record)
        }
        for item in items {
            if let record = recordsByID[item.id], !replacingPlatformIDs.contains(record.platformID) {
                record.update(with: item, seenAt: seenAt)
            } else {
                context.insert(HotNewsRecord(item: item, seenAt: seenAt))
            }
            context.insert(HotNewsTrendRecord(item: item, capturedAt: seenAt))
        }
        let trendCutoff = seenAt.addingTimeInterval(-30 * 86_400)
        let trendDescriptor = FetchDescriptor<HotNewsTrendRecord>(predicate: #Predicate { $0.capturedAt < trendCutoff })
        for record in try context.fetch(trendDescriptor) {
            context.delete(record)
        }
        try context.save()
    }

    func loadHotNews() -> [HotNewsItem] {
        guard let container else { return [] }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<HotNewsRecord>(sortBy: [SortDescriptor(\HotNewsRecord.currentRank)])
        return (try? context.fetch(descriptor).map(\.asItem)) ?? []
    }

    func loadHotNewsLastUpdated() -> Date? {
        guard let container else { return nil }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<HotNewsRecord>(sortBy: [SortDescriptor(\HotNewsRecord.lastSeenAt, order: .reverse)])
        let records = (try? context.fetch(descriptor)) ?? []
        return records.first?.lastSeenAt
    }

    func loadHotNewsTrend(for topicKey: String, limit: Int = 24) -> [(date: Date, rank: Int)] {
        guard let container else { return [] }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<HotNewsTrendRecord>(
            predicate: #Predicate { $0.topicKey == topicKey },
            sortBy: [SortDescriptor(\HotNewsTrendRecord.capturedAt, order: .reverse)]
        )
        let records = (try? context.fetch(descriptor)) ?? []
        return Array(records.prefix(limit).map { (date: $0.capturedAt, rank: $0.rank) }.reversed())
    }

    private func migrateLegacyJSON(into context: ModelContext) {
        let legacyItems = loadLegacyJSON()
        for item in legacyItems { context.insert(NewsRecord(from: item)) }
        try? context.save()
    }

    private func update(_ record: NewsRecord, from item: NewsItem) {
        record.title = item.title
        record.source = item.source
        record.urlString = item.url?.absoluteString
        record.publishedAt = item.publishedAt
        record.summary = item.summary
        record.isRead = item.isRead
        record.isFavorite = item.isFavorite
    }

    private func loadLegacyJSON() -> [NewsItem] {
        guard let data = try? Data(contentsOf: legacyFileURL),
              let items = try? JSONDecoder.trendRadar.decode([NewsItem].self, from: data) else { return [] }
        return items
    }

    private func saveLegacyJSON(_ items: [NewsItem]) {
        guard let data = try? JSONEncoder.trendRadar.encode(items) else { return }
        try? data.write(to: legacyFileURL, options: .atomic)
    }
}

enum LocalStoreError: Error {
    case unavailable
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
