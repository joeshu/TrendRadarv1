import Foundation

struct WebhookDeliveryRecord: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let createdAt: Date
    let reportID: String?
    let status: Int?
    let success: Bool
    let attempts: Int
    let message: String
    let channel: String?
    let batchIndex: Int?
    let batchTotal: Int?
    let responseSummary: String?

    init(reportID: String?, status: Int?, success: Bool, attempts: Int, message: String, createdAt: Date = Date(), channel: String? = nil, batchIndex: Int? = nil, batchTotal: Int? = nil, responseSummary: String? = nil) {
        id = UUID().uuidString
        self.createdAt = createdAt
        self.reportID = reportID
        self.status = status
        self.success = success
        self.attempts = attempts
        self.message = message
        self.channel = channel
        self.batchIndex = batchIndex
        self.batchTotal = batchTotal
        self.responseSummary = responseSummary
    }
}

enum WebhookChannel: String, Sendable {
    case generic
    case feishu
    case dingtalk
    case wework
}

struct WebhookPayloadRenderer: Sendable {
    func render(report: ReportDetail, template: String, batchContent: String, batchIndex: Int, batchTotal: Int, channel: WebhookChannel = .generic) throws -> Data {
        let reportJSON = try JSONEncoder.webhook.encode(report)
        let evidence = ReportPresentationModel(report: report).evidence
        if template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && channel != .generic {
            switch channel {
            case .feishu:
                return try JSONSerialization.data(withJSONObject: ["msg_type": "text", "content": ["text": batchContent]], options: [.sortedKeys])
            case .dingtalk:
                return try JSONSerialization.data(withJSONObject: ["msgtype": "markdown", "markdown": ["title": report.title, "text": batchContent]], options: [.sortedKeys])
            case .wework:
                return try JSONSerialization.data(withJSONObject: ["msgtype": "markdown", "markdown": ["content": batchContent]], options: [.sortedKeys])
            case .generic: break
            }
        }
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
                "schema_version": report.metadata.schemaVersion,
                "title": report.title,
                "content": batchContent,
                "report_type": report.type.rawValue,
                "generated_at": values["generated_at"] ?? "",
                "data_complete": !report.metadata.isPartial,
                "sample_count": evidence.sampleCount,
                "matched_count": evidence.matchedCount,
                "source_count": evidence.sourceCount,
                "failed_source_count": evidence.failedSourceCount,
                "citation_count": evidence.citedItemCount,
                "window_start": (evidence.windowStart.map { ISO8601DateFormatter().string(from: $0) } as Any?) ?? NSNull(),
                "window_end": ISO8601DateFormatter().string(from: evidence.windowEnd),
                "generation_method": evidence.generationMethod,
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
        return await deliver(report: report, urlValue: urlValue, template: settings.notification.channels.genericPayloadTemplate, channel: .generic, maxBytes: settings.advanced.defaultBatchSize)
    }

    @discardableResult
    func sendConfiguredChannels(report: ReportDetail, settings: AppSettings) async -> Bool {
        guard settings.notification.enabled else { return false }
        var configured: [(WebhookChannel, String, String, Int)] = []
        let channels = settings.notification.channels
        let feishu = keychain.read("notify-feishu").trimmingCharacters(in: .whitespacesAndNewlines)
        let dingtalk = keychain.read("notify-dingtalk").trimmingCharacters(in: .whitespacesAndNewlines)
        let wework = keychain.read("notify-wework").trimmingCharacters(in: .whitespacesAndNewlines)
        let generic = keychain.read("notify-generic").trimmingCharacters(in: .whitespacesAndNewlines)
        if !feishu.isEmpty { configured.append((.feishu, feishu, "", settings.advanced.feishuBatchSize)) }
        if !dingtalk.isEmpty { configured.append((.dingtalk, dingtalk, "", settings.advanced.dingtalkBatchSize)) }
        if !wework.isEmpty { configured.append((.wework, wework, "", settings.advanced.defaultBatchSize)) }
        if !generic.isEmpty { configured.append((.generic, generic, channels.genericPayloadTemplate, settings.advanced.defaultBatchSize)) }
        guard !configured.isEmpty else { return true }
        var allSucceeded = true
        for (channel, url, template, limit) in configured {
            if !(await deliver(report: report, urlValue: url, template: template, channel: channel, maxBytes: max(500, limit))) { allSucceeded = false }
        }
        return allSucceeded
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
        _ = await deliver(report: detail, urlValue: urlValue, template: settings.notification.channels.genericPayloadTemplate, channel: .generic, maxBytes: settings.advanced.defaultBatchSize)
        return Self.records().first ?? WebhookDeliveryRecord(reportID: nil, status: nil, success: false, attempts: 0, message: GenericWebhookError.emptyResponse.localizedDescription)
    }

    private func deliver(report: ReportDetail, urlValue: String, template: String, channel: WebhookChannel, maxBytes: Int) async -> Bool {
        guard let url = URL(string: urlValue), url.scheme?.lowercased() == "https" else {
            Self.record(WebhookDeliveryRecord(reportID: report.id.uuidString, status: nil, success: false, attempts: 0, message: GenericWebhookError.invalidURL.localizedDescription, channel: channel.rawValue))
            return false
        }
        let content = ReportFormatter().render(report, format: .markdown)
        let chunks = split(content, maxBytes: maxBytes)
        var allSucceeded = true
        for (offset, chunk) in chunks.enumerated() {
            do {
                let decorated = chunks.count > 1 ? "【TrendRadar \(offset + 1)/\(chunks.count)】\n\(chunk)\n\n— 报告结束：\(report.title) —" : chunk
                let payload = try renderer.render(report: report, template: template, batchContent: decorated, batchIndex: offset + 1, batchTotal: chunks.count, channel: channel)
                let result = try await post(payload, to: url)
                Self.record(WebhookDeliveryRecord(reportID: report.id.uuidString, status: result.statusCode, success: true, attempts: result.attempts, message: "第 \(offset + 1)/\(chunks.count) 批已发送", channel: channel.rawValue, batchIndex: offset + 1, batchTotal: chunks.count, responseSummary: result.responseSummary))
            } catch {
                allSucceeded = false
                let failure = error as? WebhookRequestFailure
                Self.record(WebhookDeliveryRecord(reportID: report.id.uuidString, status: failure?.statusCode, success: false, attempts: failure?.attempts ?? 0, message: error.localizedDescription, channel: channel.rawValue, batchIndex: offset + 1, batchTotal: chunks.count))
                break
            }
        }
        return allSucceeded
    }

    private func post(_ payload: Data, to url: URL) async throws -> (statusCode: Int, attempts: Int, responseSummary: String?) {
        var lastError: Error = GenericWebhookError.emptyResponse
        for attempt in 1...3 {
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.timeoutInterval = 30
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("TrendRadar-iOS/1.0", forHTTPHeaderField: "User-Agent")
                request.httpBody = payload
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw GenericWebhookError.emptyResponse }
                guard 200..<300 ~= http.statusCode else {
                    throw WebhookRequestFailure(statusCode: http.statusCode, attempts: attempt, underlying: GenericWebhookError.httpStatus(http.statusCode))
                }
                let responseSummary = String(data: data.prefix(500), encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return (http.statusCode, attempt, responseSummary?.isEmpty == true ? nil : responseSummary)
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
