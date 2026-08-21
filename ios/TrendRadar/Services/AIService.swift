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

        return try await requestContent(
            url: url,
            apiKey: apiKey,
            models: modelCandidates(primary: model, settings: settings),
            messages: [
                Message(role: "system", content: "请用简体中文概括新闻，输出不超过三句话。"),
                Message(role: "user", content: item.title + "\n" + (item.summary ?? ""))
            ],
            settings: settings
        )
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
        let input = analysisItems.enumerated().map { index, item in
            "\(index + 1). [\(item.source)] \(item.title)\(item.summary.map { "\n   \($0)" } ?? "")"
        }.joined(separator: "\n")
        let prompt = AIPromptTemplate.load(fileName: settings.aiAnalysis.promptFile)
        let messages = prompt.messages(values: [
            "language": settings.aiAnalysis.language,
            "report_mode": settings.aiAnalysis.mode,
            "report_type": settings.report.mode,
            "current_time": Date().formatted(date: .abbreviated, time: .shortened),
            "news_count": String(analysisItems.count),
            "rss_count": String(analysisItems.filter { $0.source.lowercased().contains("rss") }.count),
            "keywords": settings.keywords.joined(separator: ", "),
            "platforms": Array(Set(analysisItems.map(\.source))).sorted().joined(separator: ", "),
            "news_content": input,
            "rss_content": settings.aiAnalysis.includeRSS ? input : "暂无RSS数据",
            "standalone_content": settings.aiAnalysis.includeStandalone ? input : "暂无独立展示区数据"
        ])
        let content = try await requestContent(
            url: url,
            apiKey: apiKey,
            models: modelCandidates(primary: model, settings: settings),
            messages: [
                Message(role: "system", content: messages.system + "\n应用接口要求：只输出包含 overview、sentimentPositive、sentimentNeutral、sentimentNegative、weakSignals、recommendation 字段的 JSON。三个情绪数值之和应为 1。"),
                Message(role: "user", content: messages.user)
            ],
            settings: settings
        )
        let json = content.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        let analysis = try JSONDecoder().decode(StructuredAIAnalysis.self, from: Data(json.utf8))
        let sentimentValues = [analysis.sentimentPositive, analysis.sentimentNeutral, analysis.sentimentNegative]
        guard sentimentValues.allSatisfy({ $0 >= 0 && $0 <= 1 }), abs(sentimentValues.reduce(0, +) - 1) < 0.02 else {
            throw AIError.invalidAnalysis
        }
        return analysis
    }

    func classify(_ items: [NewsItem], settings: AppSettings = AppSettings()) async throws -> [AIFilterMatch] {
        guard !items.isEmpty else { return [] }
        let interests = settings.ai.interests.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !interests.isEmpty else { return [] }
        let tags = settings.ai.interestTags.isEmpty
            ? interests.components(separatedBy: .newlines).map { AIInterestTag(id: 0, tag: $0, description: $0) }
            : settings.ai.interestTags
        let tagsText = tags
            .filter { !$0.tag.isEmpty }
            .enumerated()
            .map { "\($0.offset + 1). \($0.element.tag) - \($0.element.description)" }
            .joined(separator: "\n")
        let newsList = items.enumerated().map { "\($0.offset + 1). \($0.element.title)" }.joined(separator: "\n")
        let fallback = AIPromptMessages(
            system: "你是新闻分类器。只输出严格 JSON 数组。",
            user: "用户兴趣：\n{interests_content}\n分类标签：\n{tags_list}\n新闻列表：\n{news_list}\n返回 id、tag_id、score，score 范围为 0 到 1。"
        )
        let prompt = AIPromptTemplate.load(fileName: settings.ai.filterPromptFile, fallback: fallback)
        let messages = prompt.messages(values: [
            "interests_content": interests,
            "tags_list": tagsText,
            "news_count": String(items.count),
            "news_list": newsList
        ])
        let baseURL = keychain.read("api-base").trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = keychain.read("api-key")
        guard !baseURL.isEmpty, !apiKey.isEmpty else { throw AIError.missingConfiguration }
        let model = keychain.read("ai-model").trimmingCharacters(in: .whitespacesAndNewlines)
        let endpoint = baseURL.hasSuffix("/chat/completions") ? baseURL : baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/chat/completions"
        guard let url = URL(string: endpoint) else { throw AIError.invalidURL }
        let content = try await requestContent(
            url: url,
            apiKey: apiKey,
            models: modelCandidates(primary: model, settings: settings),
            messages: [Message(role: "system", content: messages.system), Message(role: "user", content: messages.user)],
            settings: settings
        )
        let json = normalizedJSON(content)
        let matches = try JSONDecoder().decode([AIFilterMatch].self, from: Data(json.utf8))
        return matches.filter { $0.id > 0 && $0.tagID > 0 && $0.score >= 0 && $0.score <= 1 }
    }

    func extractInterestTags(settings: AppSettings) async throws -> [AIInterestTag] {
        let interests = settings.ai.interests.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !interests.isEmpty else { return [] }
        let fallback = AIPromptMessages(system: "你是兴趣标签提取器。只输出严格 JSON。", user: "兴趣描述：\n{interests_content}\n返回 {\"tags\":[{\"tag\":\"名称\",\"description\":\"描述\"}]}。")
        let prompt = AIPromptTemplate.load(fileName: settings.ai.extractPromptFile, fallback: fallback)
        let messages = prompt.messages(values: ["interests_content": interests])
        let content = try await request(messages: messages, settings: settings)
        let response = try JSONDecoder().decode(AIInterestTagResponse.self, from: Data(normalizedJSON(content).utf8))
        return response.tags.enumerated().prefix(20).map { AIInterestTag(id: $0.offset + 1, tag: $0.element.tag, description: $0.element.description) }
    }

    func updateInterestTags(settings: AppSettings) async throws -> AIInterestTagUpdate {
        let interests = settings.ai.interests.trimmingCharacters(in: .whitespacesAndNewlines)
        let oldTags = try JSONEncoder().encode(settings.ai.interestTags)
        let oldTagsJSON = String(data: oldTags, encoding: .utf8) ?? "[]"
        let fallback = AIPromptMessages(system: "你是标签管理器。只输出严格 JSON。", user: "旧标签：\n{old_tags_json}\n新兴趣：\n{interests_content}\n返回 keep、add、remove、change_ratio。")
        let prompt = AIPromptTemplate.load(fileName: settings.ai.updateTagsPromptFile, fallback: fallback)
        let messages = prompt.messages(values: ["old_tags_json": oldTagsJSON, "interests_content": interests])
        let content = try await request(messages: messages, settings: settings)
        return try JSONDecoder().decode(AIInterestTagUpdate.self, from: Data(normalizedJSON(content).utf8))
    }

    func filter(_ items: [NewsItem], settings: AppSettings) async throws -> [NewsItem] {
        let matches = try await classify(items, settings: settings)
        let minimumScore = min(max(settings.ai.minimumScore, 0), 1)
        let acceptedIDs: Set<String> = Set(matches.filter { $0.score >= minimumScore }.compactMap { index in
            guard index.id > 0, index.id <= items.count else { return nil }
            return items[index.id - 1].id
        })
        return items.filter { acceptedIDs.contains($0.id) }
    }

    private func modelCandidates(primary: String, settings: AppSettings) -> [String] {
        let configured = primary.isEmpty ? "gpt-4o-mini" : primary
        var candidates: [String] = []
        for model in [configured] + settings.ai.fallbackModels {
            let normalized = model.trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalized.isEmpty, !candidates.contains(normalized) { candidates.append(normalized) }
        }
        return candidates
    }

    private func requestContent(url: URL, apiKey: String, models: [String], messages: [Message], settings: AppSettings) async throws -> String {
        var lastError: Error = AIError.emptyResponse
        let retryCount = max(settings.ai.retries, 0)
        for model in models {
            for attempt in 0...retryCount {
                do {
                    let body = RequestBody(model: model, messages: messages, temperature: settings.ai.temperature, maxTokens: settings.ai.maxTokens == 0 ? nil : settings.ai.maxTokens)
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
                    guard let content = result.choices.first?.message.content, !content.isEmpty else { throw AIError.emptyResponse }
                    return content.trimmingCharacters(in: .whitespacesAndNewlines)
                } catch {
                    lastError = error
                    if attempt < retryCount { try? await Task.sleep(for: .milliseconds(250)) }
                }
            }
        }
        throw lastError
    }

    private func request(messages: AIPromptMessages, settings: AppSettings) async throws -> String {
        let baseURL = keychain.read("api-base").trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = keychain.read("api-key")
        guard !baseURL.isEmpty, !apiKey.isEmpty else { throw AIError.missingConfiguration }
        let endpoint = baseURL.hasSuffix("/chat/completions") ? baseURL : baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/chat/completions"
        guard let url = URL(string: endpoint) else { throw AIError.invalidURL }
        return try await requestContent(url: url, apiKey: apiKey, models: modelCandidates(primary: keychain.read("ai-model"), settings: settings), messages: [Message(role: "system", content: messages.system), Message(role: "user", content: messages.user)], settings: settings)
    }

    private func normalizedJSON(_ content: String) -> String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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

struct AIFilterMatch: Codable, Equatable, Sendable {
    let id: Int
    let tagID: Int
    let score: Double

    enum CodingKeys: String, CodingKey {
        case id, score
        case tagID = "tag_id"
    }
}

private struct AIInterestTagResponse: Codable, Sendable {
    let tags: [AIInterestTagPayload]
}

struct AIInterestTagPayload: Codable, Equatable, Sendable {
    let tag: String
    let description: String
}

struct AIInterestTagUpdate: Codable, Equatable, Sendable {
    let keep: [AIInterestTagPayload]
    let add: [AIInterestTagPayload]
    let remove: [String]
    let changeRatio: Double

    enum CodingKeys: String, CodingKey {
        case keep, add, remove
        case changeRatio = "change_ratio"
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
