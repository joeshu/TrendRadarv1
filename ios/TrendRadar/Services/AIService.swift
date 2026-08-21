import Foundation

struct AIService: Sendable {
    private let keychain = KeychainStore()

    func summarize(_ item: NewsItem, settings: AppSettings = AppSettings()) async throws -> String {
        let baseURL = keychain.read("api-base").trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = keychain.read("api-key")
        let model = keychain.read("ai-model").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !baseURL.isEmpty, !apiKey.isEmpty else {
            throw AIError.missingConfiguration
        }

        let endpoint = baseURL.hasSuffix("/chat/completions")
            ? baseURL
            : baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/chat/completions"
        guard let url = URL(string: endpoint) else { throw AIError.invalidURL }

        let requestBody = RequestBody(
            model: model.isEmpty ? "gpt-4o-mini" : model,
            messages: [
                Message(role: "system", content: "请用简体中文概括新闻，输出不超过三句话。"),
                Message(role: "user", content: item.title + "\n" + (item.summary ?? ""))
            ],
            temperature: settings.ai.temperature,
            maxTokens: settings.ai.maxTokens == 0 ? nil : settings.ai.maxTokens
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = TimeInterval(settings.ai.timeout)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw AIError.server(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        let result = try JSONDecoder().decode(ResponseBody.self, from: data)
        guard let content = result.choices.first?.message.content, !content.isEmpty else {
            throw AIError.emptyResponse
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func analyze(_ items: [NewsItem], settings: AppSettings = AppSettings()) async throws -> StructuredAIAnalysis {
        guard !items.isEmpty else { throw AIError.emptyInput }
        let baseURL = keychain.read("api-base").trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = keychain.read("api-key")
        let model = keychain.read("ai-model").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !baseURL.isEmpty, !apiKey.isEmpty else { throw AIError.missingConfiguration }
        let endpoint = baseURL.hasSuffix("/chat/completions") ? baseURL : baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/chat/completions"
        guard let url = URL(string: endpoint) else { throw AIError.invalidURL }
        let analysisItems = settings.aiAnalysis.maxNewsForAnalysis > 0
            ? Array(items.prefix(settings.aiAnalysis.maxNewsForAnalysis))
            : items
        let input = analysisItems.enumerated().map { "\($0.offset + 1). \($0.element.title)" }.joined(separator: "\n")
        let body = RequestBody(model: model.isEmpty ? "gpt-4o-mini" : model, messages: [
            Message(role: "system", content: "你是新闻情报分析器。只输出合法 JSON，不要 Markdown 代码块。字段为 overview(string), sentimentPositive(number 0-1), sentimentNeutral(number 0-1), sentimentNegative(number 0-1), weakSignals(array of strings), recommendation(string)。三个情绪数值之和应为 1。"),
            Message(role: "user", content: input)
        ], temperature: settings.ai.temperature, maxTokens: settings.ai.maxTokens == 0 ? nil : settings.ai.maxTokens)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = TimeInterval(settings.ai.timeout)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw AIError.server(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        let result = try JSONDecoder().decode(ResponseBody.self, from: data)
        guard let content = result.choices.first?.message.content else { throw AIError.emptyResponse }
        let json = content.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        let analysis = try JSONDecoder().decode(StructuredAIAnalysis.self, from: Data(json.utf8))
        let sentimentValues = [analysis.sentimentPositive, analysis.sentimentNeutral, analysis.sentimentNegative]
        guard sentimentValues.allSatisfy({ $0 >= 0 && $0 <= 1 }), abs(sentimentValues.reduce(0, +) - 1) < 0.02 else {
            throw AIError.invalidAnalysis
        }
        return analysis
    }

    func reportAnalysis(for items: [NewsItem], settings: AppSettings) async -> ReportAIAnalysis {
        guard settings.ai.enabled, settings.aiAnalysis.enabled else {
            return ReportAIAnalysis(enabled: false, model: nil, language: settings.aiAnalysis.language, content: nil, failureMessage: nil)
        }
        do {
            let result = try await analyze(items, settings: settings)
            return ReportAIAnalysis(enabled: true, model: keychain.read("ai-model"), language: settings.aiAnalysis.language, content: result.overview, failureMessage: nil, sentimentPositive: result.sentimentPositive, sentimentNeutral: result.sentimentNeutral, sentimentNegative: result.sentimentNegative, weakSignals: result.weakSignals, recommendation: result.recommendation)
        } catch {
            return ReportAIAnalysis(enabled: true, model: keychain.read("ai-model"), language: settings.aiAnalysis.language, content: nil, failureMessage: error.localizedDescription)
        }
    }
}

enum AIError: LocalizedError {
    case missingConfiguration
    case invalidURL
    case server(statusCode: Int)
    case emptyResponse
    case emptyInput
    case invalidAnalysis

    var errorDescription: String? {
        switch self {
        case .missingConfiguration: return "请先在设置中配置 AI API Base URL 和 API Key"
        case .invalidURL: return "AI API 地址格式无效"
        case .server(let code): return "AI 服务返回错误（HTTP \(code)）"
        case .emptyResponse: return "AI 服务返回了空内容"
        case .emptyInput: return "当前没有可供 AI 分析的新闻"
        case .invalidAnalysis: return "AI 返回的情绪分析数据无效"
        }
    }
}

private struct RequestBody: Encodable {
    let model: String
    let messages: [Message]
    let temperature: Double
    let maxTokens: Int?

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(messages, forKey: .messages)
        try container.encode(temperature, forKey: .temperature)
        try container.encodeIfPresent(maxTokens, forKey: .maxTokens)
    }
}

private struct Message: Codable {
    let role: String
    let content: String
}

private struct ResponseBody: Decodable {
    let choices: [Choice]
}

private struct Choice: Decodable {
    let message: Message
}
