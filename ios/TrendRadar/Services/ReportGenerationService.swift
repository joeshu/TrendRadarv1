import Foundation
import CryptoKit

struct ReportGenerationRequest: Sendable {
    let batchID: String
    let type: ReportType
    let trigger: ReportTrigger
    let generatedAt: Date
    let settings: AppSettings
}

struct ReportGenerationService: Sendable {
    func generate(request: ReportGenerationRequest, items: [NewsItem], hotlistItems: [HotNewsItem] = []) -> ReportDetail {
        let groups = KeywordGroup.parse(request.settings.keywords)
        let matchingItems = items.filter { item in
            guard !request.settings.globalFilterWords.contains(where: { item.title.localizedCaseInsensitiveContains($0) }) else { return false }
            return groups.isEmpty || groups.contains { $0.matches(item.title) }
        }
        let matchingHotlistItems = hotlistItems.filter { item in
            guard !request.settings.globalFilterWords.contains(where: { item.title.localizedCaseInsensitiveContains($0) }) else { return false }
            return groups.isEmpty || groups.contains { $0.matches(item.title) }
        }
        let sections = makeSections(items: matchingItems, hotlistItems: matchingHotlistItems, groups: groups, settings: request.settings)
        let sourceCount = Set(matchingItems.map(\.source) + matchingHotlistItems.map(\.platformName)).count
        let statistics = ReportStatistics(
            newsCount: matchingItems.count + matchingHotlistItems.count,
            sourceCount: sourceCount,
            unreadCount: matchingItems.filter { !$0.isRead }.count + matchingHotlistItems.filter { !$0.isRead }.count,
            favoriteCount: matchingItems.filter(\.isFavorite).count + matchingHotlistItems.filter(\.isFavorite).count,
            keywordCount: groups.filter { group in
                matchingItems.contains { group.matches($0.title) } || matchingHotlistItems.contains { group.matches($0.title) }
            }.count,
            hotlistCount: matchingHotlistItems.count,
            rssCount: matchingItems.count,
            hotlistPlatformCount: Set(matchingHotlistItems.map(\.platformName)).count,
            rssSourceCount: Set(matchingItems.map(\.source)).count
        )
        let title = "\(request.type.displayName) · \(request.generatedAt.formatted(date: .abbreviated, time: .shortened))"
        return ReportDetail(
            id: stableReportID(for: request.batchID),
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

    private func makeSections(items: [NewsItem], hotlistItems: [HotNewsItem], groups: [KeywordGroup], settings: AppSettings) -> [ReportSection] {
        let hotlistSection = hotlistItems.isEmpty ? [] : [ReportSection(id: "hotlist", title: "热榜", items: hotlistItems.enumerated().map { index, item in
            ReportItemSnapshot(orderIndex: index, sectionID: "hotlist", sectionTitle: "热榜", item: item)
        })]
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
        let rssSections = grouped.map { sectionID, title, sectionItems in
            let limited = settings.report.maxNewsPerKeyword > 0
                ? Array(sectionItems.prefix(settings.report.maxNewsPerKeyword))
                : sectionItems
            let snapshots = limited.map { item in
                defer { index += 1 }
                return ReportItemSnapshot(orderIndex: index, sectionID: sectionID, sectionTitle: title, keyword: settings.keywords.contains(sectionID) ? sectionID : nil, item: item)
            }
            return ReportSection(id: sectionID, title: title, items: snapshots)
        }
        return hotlistSection + rssSections
    }

    private func stableReportID(for batchID: String) -> UUID {
        let digest = SHA256.hash(data: Data(batchID.utf8))
        let bytes = Array(digest.prefix(16))
        var uuidBytes = bytes
        uuidBytes[6] = (uuidBytes[6] & 0x0F) | 0x50
        uuidBytes[8] = (uuidBytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            uuidBytes[0], uuidBytes[1], uuidBytes[2], uuidBytes[3],
            uuidBytes[4], uuidBytes[5], uuidBytes[6], uuidBytes[7],
            uuidBytes[8], uuidBytes[9], uuidBytes[10], uuidBytes[11],
            uuidBytes[12], uuidBytes[13], uuidBytes[14], uuidBytes[15]
        ))
    }
}
