import SwiftUI

enum AppTheme {
    static let background = Color(red: 0.035, green: 0.055, blue: 0.10)
    static let card = Color(red: 0.075, green: 0.105, blue: 0.17)
    static let surface = Color(red: 0.055, green: 0.080, blue: 0.13)
    static let elevated = Color(red: 0.105, green: 0.14, blue: 0.22)
    static let cyan = Color(red: 0.25, green: 0.90, blue: 0.82)
    static let yellow = Color(red: 1.0, green: 0.78, blue: 0.30)
    static let pink = Color(red: 1.0, green: 0.42, blue: 0.58)
    static let red = Color(red: 1.0, green: 0.35, blue: 0.38)
    static let green = Color(red: 0.35, green: 0.85, blue: 0.55)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary = Color.white.opacity(0.38)

    static let titleFont = Font.system(.title, design: .rounded, weight: .bold)
    static let headlineFont = Font.system(.headline, design: .rounded, weight: .semibold)
    static let bodyFont = Font.system(.body, design: .default)
    static let captionFont = Font.system(.caption, design: .rounded, weight: .medium)
    static let rankFont = Font.system(.title2, design: .rounded, weight: .bold)
}

enum AppAnimation {
    static let standard = Animation.spring(response: 0.35, dampingFraction: 0.85)
}
