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
        let groups = KeywordGroup.parse(request.settings.keywords)
        let matchingItems = items.filter { item in
            guard !request.settings.globalFilterWords.contains(where: { item.title.localizedCaseInsensitiveContains($0) }) else { return false }
            return groups.isEmpty || groups.contains { $0.matches(item.title) }
        }
        let sections = makeSections(items: matchingItems, groups: groups, settings: request.settings)
        let sourceCount = Set(matchingItems.map(\.source)).count
        let statistics = ReportStatistics(
            newsCount: matchingItems.count,
            sourceCount: sourceCount,
            unreadCount: matchingItems.filter { !$0.isRead }.count,
            favoriteCount: matchingItems.filter(\.isFavorite).count,
            keywordCount: groups.filter { group in
                matchingItems.contains { group.matches($0.title) }
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

    private func makeSections(items: [NewsItem], groups: [KeywordGroup], settings: AppSettings) -> [ReportSection] {
        let grouped: [(String, String, [NewsItem])]
        if settings.report.displayMode == "platform" {
            grouped = Dictionary(grouping: items, by: \.source).map { ($0.key, $0.key, $0.value) }
        } else if settings.keywords.isEmpty {
            grouped = [("all", "全部情报", items)]
        } else {
            grouped = groups.compactMap { group in
                let matching = items.filter { group.matches($0.title) }
                let limited = group.maxCount > 0 ? Array(matching.prefix(group.maxCount)) : matching
                return limited.isEmpty ? nil : (group.displayName, group.displayName, limited)
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
