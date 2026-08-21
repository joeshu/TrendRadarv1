import Foundation

struct AIPromptMessages: Sendable, Equatable {
    let system: String
    let user: String
}

struct AIPromptTemplate: Sendable {
    static let fallback = AIPromptMessages(
        system: "你是新闻情报分析器。只输出合法 JSON，不要 Markdown 代码块。",
        user: "请分析以下新闻：\n{news_content}"
    )

    static func load(fileName: String, bundle: Bundle = .main) -> AIPromptTemplate {
        let resourceName = (fileName as NSString).deletingPathExtension
        let resourceExtension = (fileName as NSString).pathExtension.isEmpty ? "txt" : (fileName as NSString).pathExtension
        let content = bundle.url(forResource: resourceName, withExtension: resourceExtension)
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
        return AIPromptTemplate(content: content)
    }

    private let content: String?

    init(content: String?) {
        self.content = content
    }

    func messages(values: [String: String]) -> AIPromptMessages {
        guard let content, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return Self.fallback.replacing(values: values)
        }
        let sections = Self.parseSections(content)
        let system = sections["system"] ?? Self.fallback.system
        let user = sections["user"] ?? content
        return AIPromptMessages(system: Self.replace(system, values: values), user: Self.replace(user, values: values))
    }

    private static func parseSections(_ content: String) -> [String: String] {
        var result: [String: String] = [:]
        var current: String?
        var lines: [String] = []
        func flush() {
            if let current { result[current] = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) }
            lines.removeAll(keepingCapacity: true)
        }
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "[system]" || trimmed == "[user]" {
                flush()
                current = String(trimmed.dropFirst().dropLast())
            } else if current != nil {
                lines.append(line)
            }
        }
        flush()
        return result
    }

    private static func replace(_ content: String, values: [String: String]) -> String {
        values.reduce(content) { partial, pair in
            partial.replacingOccurrences(of: "{\(pair.key)}", with: pair.value)
        }
    }
}

private extension AIPromptMessages {
    func replacing(values: [String: String]) -> AIPromptMessages {
        AIPromptMessages(
            system: values.reduce(system) { $0.replacingOccurrences(of: "{\($1.key)}", with: $1.value) },
            user: values.reduce(user) { $0.replacingOccurrences(of: "{\($1.key)}", with: $1.value) }
        )
    }
}
