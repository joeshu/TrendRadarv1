import SwiftUI

/// Renders the AI report contract as readable rich text without Markdown parsing.
struct ReportRichText: View {
    let content: String
    var body: some View {
        Text(attributedContent)
            .textSelection(.enabled)
            .lineSpacing(5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var attributedContent: AttributedString {
        let normalized = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var output = AttributedString()
        let lines = normalized.components(separatedBy: "\\n")
        for (index, line) in lines.enumerated() {
            var rendered = AttributedString(line)
            rendered.font = .body
            rendered.foregroundColor = AppTheme.textSecondary
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("【") {
                rendered.font = .headline
                rendered.foregroundColor = AppTheme.brandCyan
            } else if line.range(of: "^\\s*[0-9]+\\.\\s*", options: .regularExpression) != nil {
                rendered.font = .subheadline
                rendered.foregroundColor = AppTheme.textPrimary
            }
            output.append(rendered)
            if index < lines.count - 1 {
                output.append(AttributedString("\\n"))
            }
        }
        return output
    }

}
