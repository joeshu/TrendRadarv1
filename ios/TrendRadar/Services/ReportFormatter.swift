import Foundation

enum ReportFormat: Equatable {
    case plainText
    case markdown
}

struct ReportFormatter {
    func render(_ report: ReportDetail, format: ReportFormat) -> String {
        let heading = format == .markdown ? "# \(report.title)" : report.title
        let stats = "总新闻：\(report.statistics.newsCount) 条（热榜 \(report.statistics.hotlistCount) + RSS \(report.statistics.rssCount)）"
        var lines = [heading, stats, "热榜：\(report.statistics.hotlistCount)（平台 \(report.statistics.hotlistPlatformCount)）", "RSS：\(report.statistics.rssCount)（源 \(report.statistics.rssSourceCount)）", "类型：\(report.type.displayName)", "时间：\(report.generatedAt.formatted(date: .long, time: .shortened))"]
        if let analysis = report.aiAnalysis, analysis.hasContent {
            let content = analysis.content ?? ""
            lines.append(format == .markdown ? "\n## AI 热点分析\n\(content)" : "\nAI 热点分析\n\(content)")
            if let controversy = analysis.sentimentControversy, !controversy.isEmpty { lines.append("舆论风向争议：\(controversy)") }
            if let rssInsights = analysis.rssInsights, !rssInsights.isEmpty { lines.append("RSS 深度洞察：\(rssInsights)") }
            if let positive = analysis.sentimentPositive,
               let neutral = analysis.sentimentNeutral,
               let negative = analysis.sentimentNegative {
                lines.append("情绪：正面 \(Int(positive * 100))% · 中性 \(Int(neutral * 100))% · 负面 \(Int(negative * 100))%")
            }
            if !analysis.weakSignals.isEmpty {
                lines.append("弱信号：\(analysis.weakSignals.joined(separator: "、"))")
            }
            if let recommendation = analysis.recommendation, !recommendation.isEmpty {
                lines.append("策略建议：\(recommendation)")
            }
            if !analysis.standaloneSummaries.isEmpty {
                lines.append("独立源点速览")
                lines.append(contentsOf: analysis.standaloneSummaries.sorted { $0.key < $1.key }.map { "[\($0.key)] \($0.value)" })
            }
        } else if let message = report.aiAnalysis?.failureMessage {
            lines.append("\nAI 洞察\n分析失败：\(message)")
        }
        for section in report.sections {
            lines.append(format == .markdown ? "\n## \(section.title)" : "\n[\(section.title)]")
            lines.append(contentsOf: section.items.map { item in
                let prefix = format == .markdown ? "- " : "• "
                let rank = item.rank.map { " · 排名 \($0)" } ?? ""
                return "\(prefix)\(item.title) · \(item.source)\(rank)"
            })
        }
        return lines.joined(separator: "\n")
    }
}
