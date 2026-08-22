import Foundation

struct RefreshExecutionRecord: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let trigger: RefreshBatchTrigger
    let startedAt: Date
    let finishedAt: Date?
    let status: RefreshBatchStatus
    let reportID: String?
    let errorMessages: [String: String]

    init(
        id: String = UUID().uuidString,
        trigger: RefreshBatchTrigger,
        startedAt: Date = Date(),
        finishedAt: Date? = Date(),
        status: RefreshBatchStatus,
        reportID: String? = nil,
        errorMessages: [String: String] = [:]
    ) {
        self.id = id
        self.trigger = trigger
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.status = status
        self.reportID = reportID
        self.errorMessages = errorMessages
    }
}

enum RefreshExecutionLog {
    private static let key = "trendradar.refresh.execution.log"
    private static let maxRecords = 50

    static func record(_ value: RefreshExecutionRecord) {
        var records = load()
        records.insert(value, at: 0)
        records = Array(records.prefix(maxRecords))
        if let data = try? JSONEncoder.trendRadar.encode(records) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func load() -> [RefreshExecutionRecord] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder.trendRadar.decode([RefreshExecutionRecord].self, from: data)) ?? []
    }

    static var latest: RefreshExecutionRecord? { load().first }

    static func shouldCompensate(now: Date = Date(), interval: TimeInterval) -> Bool {
        guard let latest else { return true }
        guard latest.status == .completed || latest.status == .partial else { return true }
        guard let finishedAt = latest.finishedAt else { return true }
        return now.timeIntervalSince(finishedAt) >= max(interval, 300)
    }
}

private extension JSONEncoder {
    static var trendRadar: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var trendRadar: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
