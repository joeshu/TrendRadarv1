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

struct FilterPreview: Sendable, Equatable {
    let matches: Bool
    let isStandalone: Bool
    let matchedRules: [String]
}

struct FilterEngine: Sendable {
    let rules: KeywordRuleSet
    let standalonePlatformIDs: Set<String>
    let standaloneFeedIDs: Set<String>

    init(settings: AppSettings) {
        rules = KeywordRuleSet(keywords: settings.keywords, globalExcluded: settings.globalFilterWords)
        standalonePlatformIDs = Set(settings.display.standalonePlatforms)
        standaloneFeedIDs = Set(settings.display.standaloneRSSFeeds)
    }

    func preview(_ item: IntelligenceItem) -> FilterPreview {
        let standalone = item.sourceType == .hotlist
            ? standalonePlatformIDs.contains(item.sourceID)
            : standaloneFeedIDs.contains(item.sourceID)
        if standalone {
            return FilterPreview(matches: true, isStandalone: true, matchedRules: ["独立展示源"])
        }
        let matches = rules.matches(item.title)
        let matchedRules = rules.normal.filter { item.title.localizedCaseInsensitiveContains($0) }
            + rules.required.filter { item.title.localizedCaseInsensitiveContains($0) }
        return FilterPreview(matches: matches, isStandalone: false, matchedRules: matchedRules)
    }

    func includes(_ item: IntelligenceItem) -> Bool {
        preview(item).matches
    }

    func includes(_ item: NewsItem) -> Bool {
        preview(item).matches
    }

    func preview(_ item: NewsItem) -> FilterPreview {
        let intelligence = IntelligenceItem(
            id: item.id,
            sourceType: .rss,
            sourceID: item.source,
            sourceName: item.source,
            title: item.title,
            url: item.url,
            publishedAt: item.publishedAt,
            summary: item.summary,
            topicKey: item.title,
            isRead: item.isRead,
            isFavorite: item.isFavorite
        )
        return preview(intelligence)
    }

    func includes(_ item: HotNewsItem) -> Bool {
        preview(item).matches
    }

    func preview(_ item: HotNewsItem) -> FilterPreview {
        let intelligence = IntelligenceItem(
            id: item.id,
            sourceType: .hotlist,
            sourceID: item.platformID,
            sourceName: item.platformName,
            title: item.title,
            url: item.url,
            publishedAt: item.publishedAt,
            summary: item.extraInfo,
            topicKey: item.topicKey,
            rank: item.rank,
            previousRank: item.previousRank,
            isRead: item.isRead,
            isFavorite: item.isFavorite
        )
        return preview(intelligence)
    }
}

struct KeywordGroup: Sendable, Equatable {
    let displayName: String
    let normal: [String]
    let required: [String]
    let excluded: [String]
    let maxCount: Int

    static func parse(_ entries: [String]) -> [KeywordGroup] {
        entries.compactMap { entry in
            let tokens = entry.split { $0 == "," || $0 == "，" || $0 == " " || $0 == "\n" }.map(String.init)
            guard !tokens.isEmpty else { return nil }
            let alias = tokens.first.flatMap { token -> String? in
                guard token.hasPrefix("[") && token.hasSuffix("]") else { return nil }
                return String(token.dropFirst().dropLast())
            }
            let content = alias == nil ? tokens : Array(tokens.dropFirst())
            var normal: [String] = []
            var required: [String] = []
            var excluded: [String] = []
            var maxCount = 0
            for token in content {
                if token.hasPrefix("+") { required.append(String(token.dropFirst())) }
                else if token.hasPrefix("!") { excluded.append(String(token.dropFirst())) }
                else if token.hasPrefix("@"), let value = Int(token.dropFirst()), value > 0 { maxCount = value }
                else { normal.append(token) }
            }
            guard !normal.isEmpty || !required.isEmpty else { return nil }
            let name = alias ?? (normal + required).joined(separator: " / ")
            return KeywordGroup(displayName: name, normal: normal, required: required, excluded: excluded, maxCount: maxCount)
        }
    }

    func matches(_ text: String) -> Bool {
        let normalized = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        guard !excluded.contains(where: { normalized.localizedCaseInsensitiveContains($0) }) else { return false }
        guard required.allSatisfy({ normalized.localizedCaseInsensitiveContains($0) }) else { return false }
        return normal.isEmpty || normal.contains { normalized.localizedCaseInsensitiveContains($0) }
    }
}
