import Foundation

enum ReportFormat: Equatable {
    case plainText
    case markdown
}

struct ReportFormatter {
    func render(_ report: ReportDetail, format: ReportFormat) -> String {
        let markdown = ReportMarkdownRenderer().render(report)
        guard format == .markdown else { return stripMarkdown(markdown) }
        return markdown
    }

    private func stripMarkdown(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"\[([^\]]+)\]\([^\)]+\)"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "### ", with: "")
            .replacingOccurrences(of: "## ", with: "")
            .replacingOccurrences(of: "# ", with: "")
            .replacingOccurrences(of: "> ", with: "")
            .replacingOccurrences(of: "`", with: "")
    }
}
