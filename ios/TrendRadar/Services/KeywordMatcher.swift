import Foundation

struct KeywordRuleSet: Sendable, Equatable {
    let normal: [String]
    let required: [String]
    let excluded: [String]
    let globalExcluded: [String]

    init(keywords: [String], globalExcluded: [String]) {
        var normal: [String] = []
        var required: [String] = []
        var excluded: [String] = []
        for token in keywords.flatMap(Self.tokens(from:)) {
            guard token.count > 1 else { continue }
            if token.hasPrefix("+") {
                required.append(String(token.dropFirst()))
            } else if token.hasPrefix("!") {
                excluded.append(String(token.dropFirst()))
            } else if !token.hasPrefix("@") {
                normal.append(token)
            }
        }
        self.normal = normal
        self.required = required
        self.excluded = excluded
        self.globalExcluded = globalExcluded
    }

    func matches(_ text: String) -> Bool {
        let normalized = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        if globalExcluded.contains(where: { normalized.localizedCaseInsensitiveContains($0) }) { return false }
        if excluded.contains(where: { normalized.localizedCaseInsensitiveContains($0) }) { return false }
        if required.contains(where: { !normalized.localizedCaseInsensitiveContains($0) }) { return false }
        return normal.isEmpty || normal.contains { normalized.localizedCaseInsensitiveContains($0) }
    }

    private static func tokens(from value: String) -> [String] {
        value.split { $0 == "," || $0 == "，" || $0 == " " || $0 == "\n" }
            .map(String.init)
    }
}
