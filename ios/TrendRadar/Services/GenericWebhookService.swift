import Foundation

struct WebhookDeliveryRecord: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let createdAt: Date
    let reportID: String?
    let status: Int?
    let success: Bool
    let attempts: Int
    let message: String

    init(reportID: String?, status: Int?, success: Bool, attempts: Int, message: String, createdAt: Date = Date()) {
        id = UUID().uuidString
        self.createdAt = createdAt
        self.reportID = reportID
        self.status = status
        self.success = success
        self.attempts = attempts
        self.message = message
    }
}

struct WebhookPayloadRenderer: Sendable {
    func render(report: ReportDetail, template: String, batchContent: String, batchIndex: Int, batchTotal: Int) throws -> Data {
        let reportJSON = try JSONEncoder.webhook.encode(report)
        let values = [
            "title": report.title,
            "content": batchContent,
            "markdown": ReportFormatter().render(report, format: .markdown),
            "html": ReportHTMLFormatter().render(report),
            "report_type": report.type.rawValue,
            "generated_at": ISO8601DateFormatter().string(from: report.generatedAt),
            "report_json": String(decoding: reportJSON, as: UTF8.self),
            "batch_index": String(batchIndex),
            "batch_total": String(batchTotal)
        ]
        let source = template.trimmingCharacters(in: .whitespacesAndNewlines)
        if source.isEmpty {
            return try JSONSerialization.data(withJSONObject: [
                "title": report.title,
                "content": batchContent,
                "report_type": report.type.rawValue,
                "generated_at": values["generated_at"] ?? "",
                "batch_index": batchIndex,
                "batch_total": batchTotal
            ], options: [.sortedKeys])
        }
        var payload = source
        for (key, value) in values {
            // The placeholder represents a JSON string value. This supports templates
            // such as {"content":"{content}"} without allowing malformed JSON.
            let escaped = try jsonStringBody(value)
            payload = payload.replacingOccurrences(of: "{\(key)}", with: escaped)
        }
        guard let data = payload.data(using: .utf8) else { throw GenericWebhookError.invalidTemplate }
        _ = try JSONSerialization.jsonObject(with: data)
        return data
    }

    private func jsonStringBody(_ value: String) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: [value])
        let string = String(decoding: data, as: UTF8.self)
        // JSONSerialization wraps a scalar in an array. Strip both the array
        // brackets and the scalar's surrounding JSON quotes, preserving escapes.
        return String(string.dropFirst(2).dropLast(2))
    }
}

enum GenericWebhookError: LocalizedError {
    case missingURL
    case invalidURL
    case invalidTemplate
    case httpStatus(Int)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingURL: return "未配置通用 Webhook URL"
        case .invalidURL: return "Webhook URL 必须是有效的 HTTPS 地址"
        case .invalidTemplate: return "Webhook JSON 模板不是合法 JSON"
        case .httpStatus(let code): return "Webhook 返回 HTTP \(code)"
        case .emptyResponse: return "Webhook 未返回有效响应"
        }
    }
}

struct GenericWebhookService: Sendable {
    private let keychain = KeychainStore()
    private let renderer = WebhookPayloadRenderer()
    private static let logKey = "trendradar.webhook.delivery.log"
    private static let maxLogRecords = 50
    private static let batchSize = 10_000

    static func records() -> [WebhookDeliveryRecord] {
        guard let data = UserDefaults.standard.data(forKey: logKey) else { return [] }
        return (try? JSONDecoder.webhook.decode([WebhookDeliveryRecord].self, from: data)) ?? []
    }

    private static func record(_ value: WebhookDeliveryRecord) {
        var values = records()
        values.insert(value, at: 0)
        if let data = try? JSONEncoder.webhook.encode(Array(values.prefix(maxLogRecords))) {
            UserDefaults.standard.set(data, forKey: logKey)
        }
    }

    @discardableResult
    func send(report: ReportDetail, settings: AppSettings) async -> Bool {
        guard settings.notification.enabled else { return false }
        let urlValue = keychain.read("notify-generic").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !urlValue.isEmpty else { return false }
        return await deliver(report: report, urlValue: urlValue, template: settings.notification.channels.genericPayloadTemplate)
    }

    @discardableResult
    func sendTest(settings: AppSettings) async -> WebhookDeliveryRecord {
        let now = Date()
        let detail = ReportDetail(
            id: UUID(), title: "TrendRadar Webhook 测试", type: .manual, trigger: .manual,
            generatedAt: now, status: .completed,
            statistics: ReportStatistics(newsCount: 1, sourceCount: 1, rssCount: 1, rssSourceCount: 1),
            settingsSnapshot: ReportSettingsSnapshot(settings: settings, reportType: .manual, generatedAt: now),
            aiAnalysis: nil,
            sections: [ReportSection(id: "test", title: "测试数据", items: [ReportItemSnapshot(orderIndex: 0, sectionID: "test", sectionTitle: "测试数据", item: NewsItem(id: "webhook-test", title: "这是一条 Webhook 测试报告", source: "TrendRadar"))])],
            isFavorite: false, failureMessage: nil
        )
        let urlValue = keychain.read("notify-generic").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !urlValue.isEmpty else {
            let result = WebhookDeliveryRecord(reportID: nil, status: nil, success: false, attempts: 0, message: GenericWebhookError.missingURL.localizedDescription)
            Self.record(result)
            return result
        }
        _ = await deliver(report: detail, urlValue: urlValue, template: settings.notification.channels.genericPayloadTemplate)
        return Self.records().first ?? WebhookDeliveryRecord(reportID: nil, status: nil, success: false, attempts: 0, message: GenericWebhookError.emptyResponse.localizedDescription)
    }

    private func deliver(report: ReportDetail, urlValue: String, template: String) async -> Bool {
        guard let url = URL(string: urlValue), url.scheme?.lowercased() == "https" else {
            Self.record(WebhookDeliveryRecord(reportID: report.id.uuidString, status: nil, success: false, attempts: 0, message: GenericWebhookError.invalidURL.localizedDescription))
            return false
        }
        let content = ReportFormatter().render(report, format: .markdown)
        let chunks = split(content, maxBytes: Self.batchSize)
        var allSucceeded = true
        for (offset, chunk) in chunks.enumerated() {
            do {
                let payload = try renderer.render(report: report, template: template, batchContent: chunk, batchIndex: offset + 1, batchTotal: chunks.count)
                let result = try await post(payload, to: url)
                Self.record(WebhookDeliveryRecord(reportID: report.id.uuidString, status: result.statusCode, success: true, attempts: result.attempts, message: "第 \(offset + 1)/\(chunks.count) 批已发送"))
            } catch {
                allSucceeded = false
                let failure = error as? WebhookRequestFailure
                Self.record(WebhookDeliveryRecord(reportID: report.id.uuidString, status: failure?.statusCode, success: false, attempts: failure?.attempts ?? 0, message: error.localizedDescription))
                break
            }
        }
        return allSucceeded
    }

    private func post(_ payload: Data, to url: URL) async throws -> (statusCode: Int, attempts: Int) {
        var lastError: Error = GenericWebhookError.emptyResponse
        for attempt in 1...3 {
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.timeoutInterval = 30
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("TrendRadar-iOS/1.0", forHTTPHeaderField: "User-Agent")
                request.httpBody = payload
                let (_, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw GenericWebhookError.emptyResponse }
                guard 200..<300 ~= http.statusCode else {
                    throw WebhookRequestFailure(statusCode: http.statusCode, attempts: attempt, underlying: GenericWebhookError.httpStatus(http.statusCode))
                }
                return (http.statusCode, attempt)
            } catch {
                lastError = error
                let status = (error as? WebhookRequestFailure)?.statusCode
                let retryable = status == nil || status == 408 || status == 429 || (status.map { (500...599).contains($0) } ?? false)
                if attempt < 3 && retryable {
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 750_000_000)
                    continue
                }
                throw WebhookRequestFailure(statusCode: status, attempts: attempt, underlying: error)
            }
        }
        throw lastError
    }

    private func split(_ value: String, maxBytes: Int) -> [String] {
        guard value.utf8.count > maxBytes else { return [value] }
        var result: [String] = []
        var current = ""
        for line in value.split(separator: "\n", omittingEmptySubsequences: false) {
            let candidate = current.isEmpty ? String(line) : current + "\n" + line
            if !current.isEmpty && candidate.utf8.count > maxBytes {
                result.append(current)
                current = String(line)
            } else {
                current = candidate
            }
        }
        if !current.isEmpty { result.append(current) }
        return result.isEmpty ? [value] : result
    }
}

private struct WebhookRequestFailure: LocalizedError {
    let statusCode: Int?
    let attempts: Int
    let underlying: Error
    var errorDescription: String? { "Webhook 投递失败（已尝试 \(attempts) 次）：\(underlying.localizedDescription)" }
}

private extension JSONEncoder {
    static var webhook: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var webhook: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
