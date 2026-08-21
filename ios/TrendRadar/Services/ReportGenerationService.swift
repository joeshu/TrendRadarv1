import Foundation

struct ReportGenerationRequest: Sendable {
    let type: ReportType
    let trigger: ReportTrigger
    let generatedAt: Date
    let settings: AppSettings
}

struct ReportGenerationService: Sendable {
    func generate(request: ReportGenerationRequest, items: [NewsItem]) -> ReportDetail {
        let matchingItems = items.filter { item in
            let blocked = request.settings.globalFilterWords.contains { item.title.localizedCaseInsensitiveContains($0) }
            let included = request.settings.keywords.isEmpty || request.settings.keywords.contains { item.title.localizedCaseInsensitiveContains($0) }
            return !blocked && included
        }

        let sections = makeSections(items: matchingItems, settings: request.settings)
        let sourceCount = Set(matchingItems.map(\.source)).count
        let statistics = ReportStatistics(
            newsCount: matchingItems.count,
            sourceCount: sourceCount,
            unreadCount: matchingItems.filter { !$0.isRead }.count,
            favoriteCount: matchingItems.filter(\.isFavorite).count,
            keywordCount: request.settings.keywords.filter { keyword in
                matchingItems.contains { $0.title.localizedCaseInsensitiveContains(keyword) }
            }.count
        )
        let title = "\(request.type.displayName) · \(request.generatedAt.formatted(date: .abbreviated, time: .shortened))"
        return ReportDetail(
            id: UUID(),
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
            grouped = settings.keywords.compactMap { keyword in
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
