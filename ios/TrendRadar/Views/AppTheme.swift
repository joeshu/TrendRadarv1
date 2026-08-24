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
    static let electricBlue = Color(red: 0.05, green: 0.63, blue: 1.0)
    static let violet = Color(red: 0.49, green: 0.25, blue: 0.96)
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
    static let pageTitleFont = Font.largeTitle.bold()
    static let titleFont = Font.title.weight(.semibold)
    static let sectionTitleFont = Font.title3.weight(.semibold)
    static let headlineFont = Font.headline.weight(.semibold)
    static let cardTitleFont = Font.headline.weight(.semibold)
    static let bodyFont = Font.body
    static let readingFont = Font.body.leading(.loose)
    static let captionFont = Font.caption
    static let metadataFont = Font.caption2.weight(.medium)
    static let brandLabelFont = Font.caption2.bold()
    static let numericFont = Font.title2.bold().monospacedDigit()
    static let rankFont = Font.title2.bold().monospacedDigit()

    static let accentGradient = LinearGradient(
        colors: [electricBlue, violet, brandMagenta],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let screenGradient = LinearGradient(
        colors: [
            adaptive(light: UIColor(red: 0.94, green: 0.97, blue: 0.995, alpha: 1), dark: UIColor(red: 0.018, green: 0.035, blue: 0.065, alpha: 1)),
            adaptive(light: UIColor(red: 0.97, green: 0.98, blue: 1.0, alpha: 1), dark: UIColor(red: 0.025, green: 0.055, blue: 0.10, alpha: 1)),
            adaptive(light: UIColor(red: 0.965, green: 0.945, blue: 0.99, alpha: 1), dark: UIColor(red: 0.055, green: 0.035, blue: 0.105, alpha: 1))
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

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

private struct AppHighContrastKey: EnvironmentKey {
    static let defaultValue = false
}

private struct AppReduceTransparencyKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var appHighContrast: Bool {
        get { self[AppHighContrastKey.self] }
        set { self[AppHighContrastKey.self] = newValue }
    }

    var appReduceTransparency: Bool {
        get { self[AppReduceTransparencyKey.self] }
        set { self[AppReduceTransparencyKey.self] = newValue }
    }
}

struct IntelligenceScreenBackground: View {
    @Environment(\.appHighContrast) private var highContrast
    @Environment(\.appReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency

    private var shouldReduceTransparency: Bool { reduceTransparency || systemReduceTransparency }

    var body: some View {
        ZStack {
            AppTheme.screenGradient
            if !shouldReduceTransparency {
                Circle()
                    .fill(AppTheme.electricBlue.opacity(highContrast ? 0.07 : 0.10))
                    .frame(width: 320, height: 320)
                    .blur(radius: 55)
                    .offset(x: -170, y: -310)
                Circle()
                    .fill(AppTheme.brandMagenta.opacity(highContrast ? 0.05 : 0.08))
                    .frame(width: 280, height: 280)
                    .blur(radius: 60)
                    .offset(x: 190, y: 330)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct IntelligenceCardModifier: ViewModifier {
    @Environment(\.appHighContrast) private var highContrast
    @Environment(\.appReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency
    let tint: Color
    let cornerRadius: CGFloat

    private var shouldReduceTransparency: Bool { reduceTransparency || systemReduceTransparency }

    func body(content: Content) -> some View {
        content
            .background {
                if shouldReduceTransparency {
                    AppTheme.card
                } else {
                    Rectangle().fill(.ultraThinMaterial)
                }
            }
            .background(AppTheme.card.opacity(highContrast ? 0.96 : 0.82))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [tint.opacity(0.34), AppTheme.cardBorder.opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: highContrast ? 1.5 : 1
                    )
            }
            .shadow(color: shouldReduceTransparency ? .clear : tint.opacity(highContrast ? 0.06 : 0.10), radius: 18, y: 8)
    }
}

extension View {
    func intelligenceCard(tint: Color = AppTheme.brandCyan, cornerRadius: CGFloat = 20) -> some View {
        modifier(IntelligenceCardModifier(tint: tint, cornerRadius: cornerRadius))
    }
}

enum AppAnimation {
    static let standard = Animation.spring(response: 0.35, dampingFraction: 0.85)
    static let slow = Animation.spring(response: 0.5, dampingFraction: 0.8)
}
