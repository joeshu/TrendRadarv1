import SwiftUI
import UIKit

enum AppTheme {
    // White technology surface: cool paper white, ink typography, electric cyan accents.
    static let background = adaptive(light: UIColor(red: 0.965, green: 0.978, blue: 0.992, alpha: 1), dark: UIColor(red: 0.035, green: 0.055, blue: 0.085, alpha: 1))
    static let card = adaptive(light: .white, dark: UIColor(red: 0.075, green: 0.105, blue: 0.15, alpha: 1))
    static let surface = adaptive(light: UIColor(red: 0.935, green: 0.955, blue: 0.978, alpha: 1), dark: UIColor(red: 0.105, green: 0.14, blue: 0.19, alpha: 1))
    static let elevated = adaptive(light: .white, dark: UIColor(red: 0.11, green: 0.145, blue: 0.20, alpha: 1))
    static let heroGradient = LinearGradient(
        colors: [
            adaptive(light: UIColor(red: 0.86, green: 0.96, blue: 1.0, alpha: 1), dark: UIColor(red: 0.08, green: 0.20, blue: 0.29, alpha: 1)),
            adaptive(light: UIColor(red: 0.94, green: 0.91, blue: 1.0, alpha: 1), dark: UIColor(red: 0.16, green: 0.13, blue: 0.29, alpha: 1))
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let brandCyan = Color(red: 0.02, green: 0.52, blue: 0.82)
    static let brandIndigo = Color(red: 0.25, green: 0.28, blue: 0.78)
    static let brandMagenta = Color(red: 0.78, green: 0.16, blue: 0.52)
    static let cardBorder = adaptive(light: UIColor(red: 0.72, green: 0.80, blue: 0.88, alpha: 0.72), dark: UIColor(red: 0.28, green: 0.38, blue: 0.50, alpha: 0.75))
    static let cyan = Color(red: 0.00, green: 0.58, blue: 0.72)
    static let yellow = Color(red: 0.86, green: 0.54, blue: 0.02)
    static let pink = Color(red: 0.82, green: 0.20, blue: 0.42)
    static let red = Color(red: 0.80, green: 0.16, blue: 0.18)
    static let green = Color(red: 0.08, green: 0.58, blue: 0.32)
    static let textPrimary = adaptive(light: UIColor(red: 0.055, green: 0.09, blue: 0.15, alpha: 1), dark: UIColor(red: 0.93, green: 0.96, blue: 0.99, alpha: 1))
    static let textSecondary = adaptive(light: UIColor(red: 0.23, green: 0.31, blue: 0.40, alpha: 1), dark: UIColor(red: 0.72, green: 0.78, blue: 0.86, alpha: 1))
    static let textTertiary = adaptive(light: UIColor(red: 0.43, green: 0.51, blue: 0.60, alpha: 1), dark: UIColor(red: 0.57, green: 0.65, blue: 0.75, alpha: 1))

    // Product typography: Chinese uses the native system sans-serif; rounded is reserved for brand eyebrow labels.
    static let titleFont = Font.system(.title, design: .default, weight: .semibold)
    static let headlineFont = Font.system(.headline, design: .default, weight: .semibold)
    static let bodyFont = Font.system(.body, design: .default)
    static let captionFont = Font.system(.caption, design: .default, weight: .regular)
    static let rankFont = Font.system(.title2, design: .default, weight: .bold)

    static func cardBackground(cornerRadius: CGFloat = 18) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(card)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(cardBorder, lineWidth: 1)
            }
            .shadow(color: brandCyan.opacity(0.07), radius: 14, y: 6)
    }

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

enum AppAnimation {
    static let standard = Animation.spring(response: 0.35, dampingFraction: 0.85)
    static let slow = Animation.spring(response: 0.5, dampingFraction: 0.8)
}
