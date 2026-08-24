import SwiftUI

struct PremiumPanel<Content: View>: View {
    let tint: Color
    let content: Content
    init(tint: Color = AppTheme.brandCyan, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }
    var body: some View {
        content
            .padding(17)
            .intelligenceCard(tint: tint)
    }
}

struct PremiumSectionHeader: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?
    let icon: String
    let tint: Color
    init(eyebrow: String? = nil, title: String, subtitle: String? = nil, icon: String, tint: Color = AppTheme.brandCyan) {
        self.eyebrow = eyebrow; self.title = title; self.subtitle = subtitle; self.icon = icon; self.tint = tint
    }
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(tint)
                .frame(width: 38, height: 38).background(tint.opacity(0.14)).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                if let eyebrow { Text(eyebrow.uppercased()).font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1.2).foregroundStyle(tint) }
                Text(title).font(AppTheme.headlineFont).foregroundStyle(AppTheme.textPrimary)
                if let subtitle { Text(subtitle).font(AppTheme.captionFont).foregroundStyle(AppTheme.textSecondary) }
            }
            Spacer(minLength: 0)
        }
    }
}

struct PremiumMetricCard: View {
    let value: String; let label: String; let icon: String; let tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: icon).font(.caption.weight(.bold)).foregroundStyle(tint)
            Text(value).font(.system(size: 23, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.textPrimary).minimumScaleFactor(0.7)
            Text(label).font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(AppTheme.textSecondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(13)
            .background(AppTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(tint.opacity(0.16), lineWidth: 1))
    }
}

struct PremiumStatusLine: View {
    let title: String; let detail: String; let isGood: Bool
    var body: some View {
        HStack(spacing: 9) {
            Circle().fill(isGood ? AppTheme.green : AppTheme.yellow).frame(width: 8, height: 8)
            Text(title).font(AppTheme.captionFont).foregroundStyle(AppTheme.textSecondary)
            Spacer(); Text(detail).font(AppTheme.captionFont).foregroundStyle(isGood ? AppTheme.green : AppTheme.yellow)
        }
    }
}

struct RadarDecoration: View {
    let count: Int
    @State private var rotation = 0.0
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle().stroke(AppTheme.brandCyan.opacity(0.16 - Double(i) * 0.035), lineWidth: 1).scaleEffect(1 - Double(i) * 0.23)
            }
            Circle().fill(AppTheme.brandCyan.opacity(0.08)).frame(width: 54, height: 54)
            Circle().fill(AppTheme.brandCyan).frame(width: 8, height: 8).shadow(color: AppTheme.brandCyan, radius: 8)
            Rectangle().fill(LinearGradient(colors: [AppTheme.brandCyan.opacity(0.75), .clear], startPoint: .leading, endPoint: .trailing)).frame(width: 118, height: 1).offset(x: 58).rotationEffect(.degrees(rotation))
            Text("\(count)").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.textPrimary).offset(y: 72)
        }.frame(width: 180, height: 180).onAppear { withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) { rotation = 360 } }
    }
}

struct PremiumTag: View {
    let text: String; let tint: Color
    var body: some View { Text(text).font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(tint).padding(.horizontal, 8).padding(.vertical, 5).background(tint.opacity(0.12)).clipShape(Capsule()) }
}

struct IntelligenceFilterChip: View {
    let title: String
    let icon: String?
    let isSelected: Bool
    let tint: Color

    init(_ title: String, icon: String? = nil, isSelected: Bool, tint: Color = AppTheme.electricBlue) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.tint = tint
    }

    var body: some View {
        HStack(spacing: 6) {
            if let icon { Image(systemName: icon) }
            Text(title)
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(isSelected ? .white : AppTheme.textSecondary)
        .padding(.horizontal, 14)
        .frame(minHeight: 36)
        .background(isSelected ? AnyShapeStyle(AppTheme.accentGradient) : AnyShapeStyle(AppTheme.surface.opacity(0.82)))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(isSelected ? Color.white.opacity(0.15) : AppTheme.cardBorder.opacity(0.55), lineWidth: 1))
        .contentShape(Capsule())
    }
}

struct IntelligencePageHeader: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let eyebrow: String
    let title: String
    let subtitle: String
    let icon: String
    let assetName: String?

    init(eyebrow: String, title: String, subtitle: String, icon: String, assetName: String? = nil) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.assetName = assetName
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(eyebrow.uppercased())
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(AppTheme.electricBlue)
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.74)
                Text(subtitle)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
            }
            Spacer()
            if !dynamicTypeSize.isAccessibilitySize {
                Image(systemName: icon)
                    .font(.system(size: 29, weight: .medium))
                    .foregroundStyle(AppTheme.accentGradient)
                    .frame(width: 54, height: 54)
                    .background(AppTheme.surface.opacity(0.76))
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(AppTheme.cardBorder.opacity(0.55), lineWidth: 1))
                    .accessibilityHidden(true)
            }
        }
        .padding(assetName == nil ? 0 : 18)
        .frame(minHeight: assetName == nil ? nil : (dynamicTypeSize.isAccessibilitySize ? 188 : 158), alignment: .bottom)
        .background {
            if let assetName {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
                    .overlay {
                        LinearGradient(
                            colors: [Color.black.opacity(0.08), Color.black.opacity(0.62)],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                    }
                    .accessibilityHidden(true)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            if assetName != nil {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppTheme.cardBorder.opacity(0.55), lineWidth: 1)
            }
        }
    }
}

struct PageVisualBanner: View {
    let assetName: String
    var height: CGFloat = 132

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipped()
            .overlay {
                LinearGradient(colors: [.clear, AppTheme.background.opacity(0.56)], startPoint: .top, endPoint: .bottom)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(AppTheme.cardBorder.opacity(0.5), lineWidth: 1))
            .accessibilityHidden(true)
    }
}
