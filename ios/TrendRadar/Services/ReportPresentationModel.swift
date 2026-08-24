import Foundation

struct ReportEvidenceSummary: Equatable, Sendable {
    let sampleCount: Int
    let matchedCount: Int
    let sourceCount: Int
    let failedSourceCount: Int
    let citedItemCount: Int
    let windowStart: Date?
    let windowEnd: Date
    let isPartial: Bool
    let generationMethod: String
}

/// The channel-neutral report view model consumed by Markdown, Webhook and HTML renderers.
/// It deliberately derives from the persisted ReportDetail so old reports remain readable.
struct ReportPresentationModel: Sendable {
    let report: ReportDetail
    let sections: [ReportSection]
    let regionOrder: [String]

    init(report: ReportDetail) {
        self.report = report
        let configured = report.settingsSnapshot.regionOrder
        self.regionOrder = configured.isEmpty
            ? ["new_items", "hotlist", "rss", "standalone", "ai_analysis"]
            : configured
        self.sections = Self.orderedSections(report.sections, regionOrder: self.regionOrder)
    }

    var hasAIAnalysis: Bool {
        report.aiAnalysis?.hasContent == true || report.aiAnalysis?.failureMessage != nil
    }

    var hasStandaloneAnalysis: Bool {
        !(report.aiAnalysis?.standaloneSummaries.isEmpty ?? true)
    }

    var evidence: ReportEvidenceSummary {
        let itemIDs = Set(report.sections.flatMap(\.items).map(\.id))
        let sampleCount = max(report.metadata.collectedItemCount, itemIDs.count)
        let matchedCount = max(report.metadata.matchedItemCount, itemIDs.count)
        let analysisMethod = report.aiAnalysis.flatMap { analysis -> String? in
            guard analysis.hasContent else { return nil }
            let model = (analysis.model ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return model.isEmpty ? "增强分析" : "增强分析 · \(model)"
        }
        return ReportEvidenceSummary(
            sampleCount: sampleCount,
            matchedCount: matchedCount,
            sourceCount: report.statistics.sourceCount,
            failedSourceCount: report.diagnostics?.failures.count ?? 0,
            citedItemCount: itemIDs.count,
            windowStart: report.metadata.windowStart,
            windowEnd: report.generatedAt,
            isPartial: report.metadata.isPartial,
            generationMethod: analysisMethod ?? "本地规则"
        )
    }

    private static func orderedSections(_ sections: [ReportSection], regionOrder: [String]) -> [ReportSection] {
        let positions = Dictionary(uniqueKeysWithValues: regionOrder.enumerated().map { ($1, $0) })
        return sections.enumerated().sorted { left, right in
            let leftRegion = region(for: left.element)
            let rightRegion = region(for: right.element)
            let leftPosition = positions[leftRegion] ?? Int.max
            let rightPosition = positions[rightRegion] ?? Int.max
            if leftPosition != rightPosition { return leftPosition < rightPosition }
            return left.offset < right.offset
        }.map(\.element)
    }

    private static func region(for section: ReportSection) -> String {
        section.id == "hotlist" || section.items.contains(where: { $0.sourceType == .hotlist }) ? "hotlist" : "rss"
    }
}

struct ReportMarkdownRenderer: Sendable {
    func render(_ report: ReportDetail) -> String {
        let model = ReportPresentationModel(report: report)
        let evidence = model.evidence
        var lines: [String] = [
            "# \(report.title)",
            "",
            "> TrendRadar · \(report.type.displayName)",
            "> 生成时间：\(date(report.generatedAt))",
            "",
            "## 📊 报告概览",
            "- 情报 \(report.statistics.newsCount) 条",
            "- 热榜 \(report.statistics.hotlistCount) 条 · \(report.statistics.hotlistPlatformCount) 个平台",
            "- RSS \(report.statistics.rssCount) 条 · \(report.statistics.rssSourceCount) 个来源",
            "- 未读 \(report.statistics.unreadCount) 条 · 收藏 \(report.statistics.favoriteCount) 条",
            "- 命中关键词 \(report.statistics.keywordCount) 个",
            "- 数据完整度：\(evidence.isPartial ? "部分完成" : "完整") · 原始采集 \(evidence.sampleCount) 条 · 命中 \(evidence.matchedCount) 条",
            "- 数据窗口：\(window(evidence))",
            "- 证据：\(evidence.citedItemCount) 条引用 · \(evidence.failedSourceCount) 个失败来源 · \(evidence.generationMethod)"
        ]

        appendTopicStats(report.topicStats, to: &lines)

        var renderedSectionIDs = Set<String>()
        for region in model.regionOrder {
            switch region {
            case "ai_analysis":
                appendAI(report.aiAnalysis, to: &lines)
            case "standalone":
                appendStandalone(report.aiAnalysis, to: &lines)
            case "new_items":
                appendNewItems(report.newItems, to: &lines)
            case "hotlist", "rss":
                for section in model.sections where sectionRegion(section) == region {
                    appendSection(section, to: &lines)
                    renderedSectionIDs.insert(section.id)
                }
            default:
                continue
            }
        }
        // Preserve data from older reports whose regionOrder predates a section.
        for section in model.sections where !renderedSectionIDs.contains(section.id) {
            appendSection(section, to: &lines)
        }
        appendDiagnostics(report.diagnostics, to: &lines)

        lines.append("")
        lines.append("---")
        lines.append("报告 ID：`\(report.id.uuidString)` · 共 \(report.sections.flatMap(\.items).count) 条")
        lines.append("协议 v\(report.metadata.schemaVersion) · App \(report.metadata.appVersion) · 时区 \(report.metadata.timeZone)")
        return lines.joined(separator: "\n")
    }

    private func appendTopicStats(_ stats: [ReportTopicStat], to lines: inout [String]) {
        guard !stats.isEmpty else { return }
        lines.append("")
        lines.append("## 🔥 热点词汇统计")
        lines.append("")
        lines.append("| 热点 | 数量 | 占比 | 热度 |")
        lines.append("|---|---:|---:|---| ")
        for stat in stats {
            lines.append("| \(stat.name) | \(stat.count) | \(percent(stat.percentage)) | \(stat.level) |")
        }
    }

    private func appendDiagnostics(_ diagnostics: ReportDiagnostics?, to lines: inout [String]) {
        guard let diagnostics, !diagnostics.failures.isEmpty else { return }
        lines.append("")
        lines.append("## ⚠️ 采集异常")
        for failure in diagnostics.failures {
            lines.append("- \(failure.source)（\(failure.sourceType == .hotlist ? "热榜" : "RSS")）：\(failure.message)")
        }
    }

    private func sectionRegion(_ section: ReportSection) -> String {
        section.id == "hotlist" || section.items.contains(where: { $0.sourceType == .hotlist }) ? "hotlist" : "rss"
    }

    private func appendSection(_ section: ReportSection, to lines: inout [String]) {
        lines.append("")
        lines.append("## \(section.title)")
        lines.append("")
        if section.items.isEmpty {
            lines.append("暂无内容。")
            return
        }
        for item in section.items {
            var line = "- "
            if let url = item.url {
                line += "[\(item.title)](\(url.absoluteString))"
            } else {
                line += item.title
            }
            line += " · \(item.source)"
            if let rank = item.rank { line += " · 排名 #\(rank)" }
            if let publishedAt = item.publishedAt { line += " · \(date(publishedAt))" }
            lines.append(line)
            if let summary = item.summary?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
                lines.append("  > \(summary.replacingOccurrences(of: "\n", with: " "))")
            }
        }
    }

    private func appendNewItems(_ items: [ReportItemSnapshot], to lines: inout [String]) {
        guard !items.isEmpty else { return }
        lines.append("")
        lines.append("## 🆕 新增热点")
        for item in items {
            let title = item.url.map { "[\(item.title)](\($0.absoluteString))" } ?? item.title
            lines.append("- \(title) · \(item.source)")
        }
    }

    private func appendStandalone(_ analysis: ReportAIAnalysis?, to lines: inout [String]) {
        guard let analysis, !analysis.standaloneSummaries.isEmpty else { return }
        lines.append("")
        lines.append("## 🧭 独立源点")
        for (source, content) in analysis.standaloneSummaries.sorted(by: { $0.key < $1.key }) {
            lines.append("")
            lines.append("### \(source)")
            lines.append(content)
        }
    }

    private func appendAI(_ analysis: ReportAIAnalysis?, to lines: inout [String]) {
        guard let analysis else { return }
        lines.append("")
        lines.append("## ✨ AI 洞察")
        if let failure = analysis.failureMessage, !failure.isEmpty {
            lines.append("分析失败：\(failure)")
        }
        append("核心趋势", analysis.content ?? analysis.coreTrends, to: &lines)
        append("关键信号", analysis.signals, to: &lines)
        append("舆论风向争议", analysis.sentimentControversy, to: &lines)
        append("RSS 深度洞察", analysis.rssInsights, to: &lines)
        if let positive = analysis.sentimentPositive, let neutral = analysis.sentimentNeutral, let negative = analysis.sentimentNegative {
            lines.append("情绪分布：正面 \(percent(positive)) · 中性 \(percent(neutral)) · 负面 \(percent(negative))")
        }
        if !analysis.weakSignals.isEmpty {
            lines.append("弱信号：\(analysis.weakSignals.joined(separator: "、"))")
        }
        append("策略建议", analysis.recommendation, to: &lines)
        if !analysis.citations.isEmpty {
            lines.append("")
            lines.append("### 引用来源")
            for citation in analysis.citations {
                if let url = citation.url {
                    lines.append("- [\(citation.title)](\(url.absoluteString)) · \(citation.source)")
                } else {
                    lines.append("- \(citation.title) · \(citation.source)")
                }
            }
        }
    }

    private func append(_ title: String, _ value: String?, to lines: inout [String]) {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        lines.append("")
        lines.append("### \(title)")
        lines.append(value)
    }

    private func date(_ value: Date) -> String {
        value.formatted(date: .numeric, time: .shortened)
    }

    private func window(_ evidence: ReportEvidenceSummary) -> String {
        guard let start = evidence.windowStart else { return "截至 \(date(evidence.windowEnd))" }
        return "\(date(start)) 至 \(date(evidence.windowEnd))"
    }

    private func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }
}
