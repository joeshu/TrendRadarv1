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
