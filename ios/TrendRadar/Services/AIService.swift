import Foundation

struct AIService: Sendable {
    private let keychain = KeychainStore()

    func summarize(_ item: NewsItem) async throws -> String {
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
            temperature: 0.2
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
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
}

enum AIError: LocalizedError {
    case missingConfiguration
    case invalidURL
    case server(statusCode: Int)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingConfiguration: return "请先在设置中配置 AI API Base URL 和 API Key"
        case .invalidURL: return "AI API 地址格式无效"
        case .server(let code): return "AI 服务返回错误（HTTP \(code)）"
        case .emptyResponse: return "AI 服务返回了空内容"
        }
    }
}

private struct RequestBody: Encodable {
    let model: String
    let messages: [Message]
    let temperature: Double
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
