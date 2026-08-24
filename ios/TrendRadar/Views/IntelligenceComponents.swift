import SwiftUI

struct IntelligencePage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            content
        }
    }
}

struct StatusBadge: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .frame(minHeight: 32)
            .background(tint.opacity(0.12), in: Capsule())
            .accessibilityElement(children: .combine)
    }
}

struct RecoveryBanner: View {
    let message: String
    let isRetrying: Bool
    let retry: () -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundStyle(AppTheme.yellow)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("安全模式")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                Button(action: retry) {
                    Label(isRetrying ? "正在重试" : "重试初始化", systemImage: "arrow.clockwise")
                        .frame(minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRetrying)
                Button("继续使用缓存", action: dismiss)
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
            }
            .font(.caption.weight(.semibold))
        }
        .padding(14)
        .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.yellow.opacity(0.45), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        .accessibilityElement(children: .contain)
    }
}
