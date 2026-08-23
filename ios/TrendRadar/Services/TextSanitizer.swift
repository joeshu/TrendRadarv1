import Foundation

/// Converts RSS snippets into readable plain text for cards and reports.
enum TextSanitizer {
    static func plainText(_ input: String?) -> String? {
        guard let input else { return nil }
        let decoded = input
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#160;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
        let stripped = decoded.replacingOccurrences(of: "</?(?:p|a|br|div|span|strong|em|b|i|ul|ol|li|img|figure|figcaption|blockquote|h[1-6])(?:\\s[^>]*)?>", with: " ", options: [.regularExpression, .caseInsensitive])
        let normalized = stripped
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }
}
