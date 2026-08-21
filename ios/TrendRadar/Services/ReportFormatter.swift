import Foundation

enum ReportFormat: Equatable {
    case plainText
    case markdown
}

struct ReportFormatter {
    func render(_ report: ReportDetail, format: ReportFormat) -> String {
        let heading = format == .markdown ? "# \(report.title)" : report.title
        let stats = "情报 \(report.statistics.newsCount) 条 · 来源 \(report.statistics.sourceCount) · 未读 \(report.statistics.unreadCount) · 收藏 \(report.statistics.favoriteCount)"
        var lines = [heading, "生成时间：\(report.generatedAt.formatted(date: .long, time: .shortened))", stats]
        if let analysis = report.aiAnalysis, analysis.hasContent {
            let content = analysis.content ?? ""
            lines.append(format == .markdown ? "\n## AI 洞察\n\(content)" : "\nAI 洞察\n\(content)")
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
        } else if let message = report.aiAnalysis?.failureMessage {
            lines.append("\nAI 洞察\n分析失败：\(message)")
        }
        for section in report.sections {
            lines.append(format == .markdown ? "\n## \(section.title)" : "\n[\(section.title)]")
            lines.append(contentsOf: section.items.map { item in
                let prefix = format == .markdown ? "- " : "• "
                return "\(prefix)\(item.title) · \(item.source)"
            })
        }
        return lines.joined(separator: "\n")
    }
}
