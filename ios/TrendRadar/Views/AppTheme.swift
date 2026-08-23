import SwiftUI

enum AppTheme {
    // White technology surface: cool paper white, ink typography, electric cyan accents.
    static let background = Color(red: 0.965, green: 0.978, blue: 0.992)
    static let card = Color.white
    static let surface = Color(red: 0.935, green: 0.955, blue: 0.978)
    static let elevated = Color.white
    static let heroGradient = LinearGradient(
        colors: [Color(red: 0.86, green: 0.96, blue: 1.0), Color(red: 0.94, green: 0.91, blue: 1.0)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let brandCyan = Color(red: 0.02, green: 0.52, blue: 0.82)
    static let brandIndigo = Color(red: 0.25, green: 0.28, blue: 0.78)
    static let brandMagenta = Color(red: 0.78, green: 0.16, blue: 0.52)
    static let cardBorder = Color(red: 0.72, green: 0.80, blue: 0.88).opacity(0.72)
    static let cyan = Color(red: 0.00, green: 0.58, blue: 0.72)
    static let yellow = Color(red: 0.86, green: 0.54, blue: 0.02)
    static let pink = Color(red: 0.82, green: 0.20, blue: 0.42)
    static let red = Color(red: 0.80, green: 0.16, blue: 0.18)
    static let green = Color(red: 0.08, green: 0.58, blue: 0.32)
    static let textPrimary = Color(red: 0.055, green: 0.09, blue: 0.15)
    static let textSecondary = Color(red: 0.23, green: 0.31, blue: 0.40)
    static let textTertiary = Color(red: 0.43, green: 0.51, blue: 0.60)

    static let titleFont = Font.system(.title, design: .rounded, weight: .bold)
    static let headlineFont = Font.system(.headline, design: .rounded, weight: .semibold)
    static let bodyFont = Font.system(.body, design: .default)
    static let captionFont = Font.system(.caption, design: .rounded, weight: .medium)
    static let rankFont = Font.system(.title2, design: .rounded, weight: .bold)

    static func cardBackground(cornerRadius: CGFloat = 18) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(card)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(cardBorder, lineWidth: 1)
            }
            .shadow(color: brandCyan.opacity(0.07), radius: 14, y: 6)
    }
}

enum AppAnimation {
    static let standard = Animation.spring(response: 0.35, dampingFraction: 0.85)
    static let slow = Animation.spring(response: 0.5, dampingFraction: 0.8)
}
