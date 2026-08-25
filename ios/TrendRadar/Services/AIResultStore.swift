import Foundation

/// 持久化 AI 筛选/翻译结果，避免刷新后丢失可解释性和重复请求。
struct AIResultStore: Sendable {
    private let url: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent("TrendRadar", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        url = directory.appendingPathComponent("ai-results.json")
    }

    func load() -> [String: AIItemResult] {
        guard let data = try? Data(contentsOf: url), let value = try? JSONDecoder().decode([String: AIItemResult].self, from: data) else { return [:] }
        return value
    }

    func save(_ results: [String: AIItemResult]) {
        guard let data = try? JSONEncoder().encode(results) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func merge(_ values: [AIItemResult]) {
        var all = load()
        for value in values { all[value.itemID] = value }
        save(all)
    }
}

struct AIItemResult: Codable, Equatable, Sendable {
    let itemID: String
    var matched: Bool
    var score: Double?
    var tagIDs: [Int]
    var translatedTitle: String?
    var analyzedAt: Date
    var filterFingerprint: String?

    init(itemID: String, matched: Bool, score: Double? = nil, tagIDs: [Int] = [], translatedTitle: String? = nil, analyzedAt: Date = Date(), filterFingerprint: String? = nil) {
        self.itemID = itemID
        self.matched = matched
        self.score = score
        self.tagIDs = tagIDs
        self.translatedTitle = translatedTitle
        self.analyzedAt = analyzedAt
        self.filterFingerprint = filterFingerprint
    }
}
