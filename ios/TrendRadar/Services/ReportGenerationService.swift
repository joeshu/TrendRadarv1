import Foundation

struct ReportGenerationRequest: Sendable {
    let batchID: String
    let type: ReportType
    let trigger: ReportTrigger
    let generatedAt: Date
    let settings: AppSettings
}

struct ReportGenerationService: Sendable {
    func generate(request: ReportGenerationRequest, items: [NewsItem]) -> ReportDetail {
        let rules = KeywordRuleSet(keywords: request.settings.keywords, globalExcluded: request.settings.globalFilterWords)
        let matchingItems = items.filter { rules.matches($0.title) }

        let sections = makeSections(items: matchingItems, settings: request.settings)
        let ruleSet = KeywordRuleSet(keywords: request.settings.keywords, globalExcluded: [])
        let sourceCount = Set(matchingItems.map(\.source)).count
        let statistics = ReportStatistics(
            newsCount: matchingItems.count,
            sourceCount: sourceCount,
            unreadCount: matchingItems.filter { !$0.isRead }.count,
            favoriteCount: matchingItems.filter(\.isFavorite).count,
            keywordCount: (ruleSet.normal + ruleSet.required).filter { keyword in
                matchingItems.contains { $0.title.localizedCaseInsensitiveContains(keyword) }
            }.count
        )
        let title = "\(request.type.displayName) · \(request.generatedAt.formatted(date: .abbreviated, time: .shortened))"
        return ReportDetail(
            id: UUID(uuidString: request.batchID) ?? UUID(),
            title: title,
            type: request.type,
            trigger: request.trigger,
            generatedAt: request.generatedAt,
            status: .completed,
            statistics: statistics,
            settingsSnapshot: ReportSettingsSnapshot(settings: request.settings, reportType: request.type, generatedAt: request.generatedAt),
            aiAnalysis: nil,
            sections: sections,
            isFavorite: false,
            failureMessage: nil
        )
    }

    private func makeSections(items: [NewsItem], settings: AppSettings) -> [ReportSection] {
        let grouped: [(String, String, [NewsItem])]
        if settings.report.displayMode == "platform" {
            grouped = Dictionary(grouping: items, by: \.source).map { ($0.key, $0.key, $0.value) }
        } else if settings.keywords.isEmpty {
            grouped = [("all", "全部情报", items)]
        } else {
            let ruleSet = KeywordRuleSet(keywords: settings.keywords, globalExcluded: [])
            let sectionKeywords = ruleSet.normal.isEmpty ? ruleSet.required : ruleSet.normal
            grouped = sectionKeywords.compactMap { keyword in
                let matching = items.filter { $0.title.localizedCaseInsensitiveContains(keyword) }
                return matching.isEmpty ? nil : (keyword, keyword, matching)
            }
        }

        var index = 0
        return grouped.map { sectionID, title, sectionItems in
            let limited = settings.report.maxNewsPerKeyword > 0
                ? Array(sectionItems.prefix(settings.report.maxNewsPerKeyword))
                : sectionItems
            let snapshots = limited.map { item in
                defer { index += 1 }
                return ReportItemSnapshot(orderIndex: index, sectionID: sectionID, sectionTitle: title, keyword: settings.keywords.contains(sectionID) ? sectionID : nil, item: item)
            }
            return ReportSection(id: sectionID, title: title, items: snapshots)
        }
    }
}
