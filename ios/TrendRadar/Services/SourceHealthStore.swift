import Foundation

actor SourceHealthStore {
    static let shared = SourceHealthStore()

    private let defaults: UserDefaults
    private let key = "trendradar.source-health.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [SourceHealth] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder.trendRadar.decode([SourceHealth].self, from: data)) ?? []
    }

    func record(sourceID: String, sourceName: String, error: String?, cacheAvailable: Bool, at date: Date = Date()) {
        var values = load()
        var health = values.first(where: { $0.sourceID == sourceID })
            ?? SourceHealth(sourceID: sourceID, sourceName: sourceName)
        health.sourceName = sourceName
        if let error {
            health.recordFailure(error, cacheAvailable: cacheAvailable)
        } else {
            health.recordSuccess(at: date, cacheAvailable: cacheAvailable)
        }
        values.removeAll { $0.sourceID == sourceID }
        values.append(health)
        if let data = try? JSONEncoder.trendRadar.encode(values.sorted { $0.sourceName < $1.sourceName }) {
            defaults.set(data, forKey: key)
        }
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
