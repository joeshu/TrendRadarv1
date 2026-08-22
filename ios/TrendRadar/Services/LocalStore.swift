import Foundation
import SwiftData

actor LocalStore {
    static let shared = LocalStore()

    private let container: ModelContainer?
    private let archiveContainer: ModelContainer?
    private let legacyFileURL: URL

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        container = Self.makeContainer(in: directory)
        archiveContainer = Self.makeArchiveContainer(in: directory)
        legacyFileURL = directory.appendingPathComponent("news-v2.json")
    }

    private static func makeContainer(in directory: URL) -> ModelContainer? {
        let schema = Schema([
            NewsRecord.self,
            ReportRecord.self,
            ReportItemRecord.self,
            HotNewsRecord.self,
            HotNewsTrendRecord.self,
            IntelligenceRecord.self,
            TopicRecord.self,
            TopicItemLinkRecord.self,
            HotlistSnapshotRecord.self,
            RefreshRunRecord.self
        ])
        do {
            let storeURL = directory.appendingPathComponent("TrendRadar-v2.store")
            let configuration = ModelConfiguration(schema: schema, url: storeURL, allowsSave: true)
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            do {
                let fallbackURL = directory.appendingPathComponent("TrendRadar-v3.store")
                let configuration = ModelConfiguration(schema: schema, url: fallbackURL, allowsSave: true)
                return try ModelContainer(for: schema, configurations: configuration)
            } catch {
                return nil
            }
        }
    }

    private static func makeArchiveContainer(in directory: URL) -> ModelContainer? {
        do {
            let schema = Schema([ArchiveRecord.self])
            let storeURL = directory.appendingPathComponent("TrendRadar-archive.store")
            let configuration = ModelConfiguration(schema: schema, url: storeURL, allowsSave: true)
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            return nil
        }
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
            if let archiveContainer {
                let archiveContext = ModelContext(archiveContainer)
                for record in try archiveContext.fetch(FetchDescriptor<ArchiveRecord>()) { archiveContext.delete(record) }
                try archiveContext.save()
            }
            return
        }
        let context = ModelContext(container)
        for record in try context.fetch(FetchDescriptor<NewsRecord>()) { context.delete(record) }
        for record in try context.fetch(FetchDescriptor<ReportItemRecord>()) { context.delete(record) }
        for record in try context.fetch(FetchDescriptor<ReportRecord>()) { context.delete(record) }
        for record in try context.fetch(FetchDescriptor<HotNewsTrendRecord>()) { context.delete(record) }
        for record in try context.fetch(FetchDescriptor<HotNewsRecord>()) { context.delete(record) }
        for record in try context.fetch(FetchDescriptor<TopicItemLinkRecord>()) { context.delete(record) }
        for record in try context.fetch(FetchDescriptor<HotlistSnapshotRecord>()) { context.delete(record) }
        for record in try context.fetch(FetchDescriptor<TopicRecord>()) { context.delete(record) }
        for record in try context.fetch(FetchDescriptor<IntelligenceRecord>()) { context.delete(record) }
        for record in try context.fetch(FetchDescriptor<RefreshRunRecord>()) { context.delete(record) }
        try context.save()
        if let archiveContainer {
            let archiveContext = ModelContext(archiveContainer)
            for record in try archiveContext.fetch(FetchDescriptor<ArchiveRecord>()) { archiveContext.delete(record) }
            try archiveContext.save()
        }
        try? FileManager.default.removeItem(at: legacyFileURL)
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

    func saveArchive(_ resource: ArchiveResource) throws {
        guard let archiveContainer else { throw LocalStoreError.unavailable }
        let context = ModelContext(archiveContainer)
        let archiveID = resource.id
        let descriptor = FetchDescriptor<ArchiveRecord>(predicate: #Predicate { $0.id == archiveID })
        if let record = try context.fetch(descriptor).first {
            record.update(with: resource)
        } else {
            context.insert(ArchiveRecord(resource: resource))
        }
        try context.save()
    }

    func loadArchive(kind: ArchiveResourceKind? = nil) -> [ArchiveResource] {
        guard let archiveContainer else { return [] }
        let context = ModelContext(archiveContainer)
        let descriptor = FetchDescriptor<ArchiveRecord>(sortBy: [SortDescriptor(\ArchiveRecord.capturedAt, order: .reverse)])
        let records = (try? context.fetch(descriptor)) ?? []
        return records.compactMap { record in
            guard kind == nil || record.kind == kind?.rawValue else { return nil }
            return record.asResource
        }
    }

    func deleteArchive(resourceID: String, kind: ArchiveResourceKind) throws {
        guard let archiveContainer else { throw LocalStoreError.unavailable }
        let context = ModelContext(archiveContainer)
        let archiveID = "\(kind.rawValue):\(resourceID)"
        let descriptor = FetchDescriptor<ArchiveRecord>(predicate: #Predicate { $0.id == archiveID })
        for record in try context.fetch(descriptor) { context.delete(record) }
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
        if !replacingPlatformIDs.isEmpty {
            try context.save()
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

    func saveIntelligenceSnapshot(
        items: [IntelligenceItem],
        topics: [IntelligenceTopic],
        batch: RefreshBatch,
        replacingSourceIDs: Set<String>
    ) throws {
        guard let container else { throw LocalStoreError.unavailable }
        let context = ModelContext(container)

        for record in try context.fetch(FetchDescriptor<TopicItemLinkRecord>()) where record.batchID == batch.id {
            context.delete(record)
        }
        for record in try context.fetch(FetchDescriptor<HotlistSnapshotRecord>()) where record.batchID == batch.id {
            context.delete(record)
        }
        for record in try context.fetch(FetchDescriptor<RefreshRunRecord>()) where record.id == batch.id {
            context.delete(record)
        }

        let existingItems = try context.fetch(FetchDescriptor<IntelligenceRecord>())
        let itemRecordsByID = existingItems.reduce(into: [String: IntelligenceRecord]()) { result, record in
            result[record.id] = record
        }
        for record in existingItems where replacingSourceIDs.contains(record.sourceID) {
            context.delete(record)
        }

        let existingTopics = try context.fetch(FetchDescriptor<TopicRecord>())
        let topicRecordsByID = existingTopics.reduce(into: [String: TopicRecord]()) { result, record in
            result[record.id] = record
        }
        for topic in topics {
            if let record = topicRecordsByID[topic.id] {
                record.update(with: topic)
            } else {
                context.insert(TopicRecord(topic: topic))
            }
        }

        let snapshotItems = items.filter { $0.sourceType == .hotlist }
        for item in items {
            if let record = itemRecordsByID[item.id], !replacingSourceIDs.contains(record.sourceID) {
                record.update(with: item)
            } else {
                context.insert(IntelligenceRecord(item: item))
            }
        }
        for topic in topics {
            for item in topic.items {
                context.insert(TopicItemLinkRecord(topicID: topic.id, itemID: item.id, batchID: batch.id, rank: item.rank, collectedAt: batch.startedAt))
            }
        }
        for item in snapshotItems {
            context.insert(HotlistSnapshotRecord(item: item, batchID: batch.id))
        }
        context.insert(RefreshRunRecord(batch: batch))
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
        record.author = item.author
        record.body = item.body
        record.bodyCachedAt = item.bodyCachedAt
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
