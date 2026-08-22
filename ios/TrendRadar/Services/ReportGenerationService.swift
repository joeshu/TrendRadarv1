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
        let displayedItems = sections.flatMap(\.items)
        let sourceCount = Set(displayedItems.map(\.source)).count
        let statistics = ReportStatistics(
            newsCount: displayedItems.count,
            sourceCount: sourceCount,
            unreadCount: displayedItems.filter { !$0.isRead }.count,
            favoriteCount: displayedItems.filter(\.isFavorite).count,
            keywordCount: groups.filter { group in
                displayedItems.contains { group.matches($0.title) }
            }.count,
            hotlistCount: displayedItems.filter { $0.sourceType == .hotlist }.count,
            rssCount: displayedItems.filter { $0.sourceType == .rss }.count,
            hotlistPlatformCount: Set(displayedItems.filter { $0.sourceType == .hotlist }.map(\.source)).count,
            rssSourceCount: Set(displayedItems.filter { $0.sourceType == .rss }.map(\.source)).count
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
        let sortedHotlist = hotlistItems.sorted { left, right in
            if left.rank != right.rank { return left.rank < right.rank }
            return left.title.localizedCompare(right.title) == .orderedAscending
        }
        let hotlistSection = !settings.display.showHotlist || sortedHotlist.isEmpty ? [] : [ReportSection(id: "hotlist", title: "热榜", items: sortedHotlist.enumerated().map { index, item in
            ReportItemSnapshot(orderIndex: index, sectionID: "hotlist", sectionTitle: "热榜", item: item)
        })]
        let grouped: [(String, String, [NewsItem])]
        if !settings.display.showRSS {
            grouped = []
        } else if settings.report.displayMode == "platform" {
            grouped = Dictionary(grouping: items, by: \.source).map { ($0.key, $0.key, sort($0.value)) }
        } else if settings.keywords.isEmpty {
            grouped = [("all", "全部情报", sort(items))]
        } else {
            let orderedGroups = settings.report.sortByPositionFirst
                ? groups
                : groups.sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
            grouped = orderedGroups.compactMap { group in
                let matching = sort(items.filter { group.matches($0.title) })
                let limited = group.maxCount > 0 ? Array(matching.prefix(group.maxCount)) : matching
                return limited.isEmpty ? nil : (group.displayName, group.displayName, limited)
            }
        }

        var index = 0
        var usedRSSIDs = Set<String>()
        let rssSections = grouped.map { sectionID, title, sectionItems in
            let limited = settings.report.maxNewsPerKeyword > 0
                ? Array(sectionItems.prefix(settings.report.maxNewsPerKeyword))
                : sectionItems
            let snapshots = limited.compactMap { item -> ReportItemSnapshot? in
                guard usedRSSIDs.insert(item.id).inserted else { return nil }
                defer { index += 1 }
                return ReportItemSnapshot(orderIndex: index, sectionID: sectionID, sectionTitle: title, keyword: settings.keywords.contains(sectionID) ? sectionID : nil, item: item)
            }
            return ReportSection(id: sectionID, title: title, items: snapshots)
        }
        let orderedRSSSections: [ReportSection]
        if settings.report.sortByPositionFirst {
            let order = groups.enumerated().reduce(into: [String: Int]()) { result, entry in
                result[entry.element.displayName] = entry.offset
            }
            orderedRSSSections = rssSections.sorted { (order[$0.id] ?? Int.max) < (order[$1.id] ?? Int.max) }
        } else {
            orderedRSSSections = rssSections.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        }
        return hotlistSection + orderedRSSSections
    }

    private func sort(_ items: [NewsItem]) -> [NewsItem] {
        items.sorted { left, right in
            let leftDate = left.publishedAt ?? .distantPast
            let rightDate = right.publishedAt ?? .distantPast
            return leftDate > rightDate
        }
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
