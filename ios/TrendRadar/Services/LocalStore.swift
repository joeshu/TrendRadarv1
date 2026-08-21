import Foundation
import SwiftData

actor LocalStore {
    private let container: ModelContainer?
    private let legacyFileURL: URL

    init() {
        container = try? ModelContainer(for: NewsRecord.self)
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
        return records.map(\.asNewsItem)
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
