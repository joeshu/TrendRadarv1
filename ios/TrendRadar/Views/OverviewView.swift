import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var store: NewsStore
    @EnvironmentObject private var hotNewsStore: HotNewsStore
    @EnvironmentObject private var reportStore: ReportStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var showingFavorites = false
    @State private var showingSettings = false

    private var unreadCount: Int { store.items.filter { !$0.isRead }.count }
    private var favoriteCount: Int { store.items.filter(\.isFavorite).count }
    private var enabledSourceCount: Int {
        settingsStore.settings.customFeeds.filter(\.isEnabled).count + settingsStore.settings.platformSources.filter(\.isEnabled).count
    }
    private var latestNews: [NewsItem] {
        Array(store.items.filter { !showingFavorites || $0.isFavorite }.prefix(4))
    }
    private var latestTopics: [HotNewsTopic] { Array(hotNewsStore.topics.prefix(5)) }
    private var failureCount: Int { store.sourceFailures.count + hotNewsStore.sourceFailures.count }

    private var overviewDynamicTypeSize: DynamicTypeSize {
        switch settingsStore.settings.display.fontScale {
        case ..<0.90: return .xSmall
        case ..<0.98: return .small
        case ..<1.06: return .medium
        case ..<1.14: return .xLarge
        case ..<1.23: return .xxLarge
        default: return .xxxLarge
        }
    }

    private var overviewHorizontalPadding: CGFloat {
        16 * settingsStore.settings.display.uiScale
    }

    private var overviewCardSpacing: CGFloat {
        settingsStore.settings.display.cardSpacing * settingsStore.settings.display.uiScale
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: overviewCardSpacing) {
                        OverviewHeroCard(date: Date())
                        sourceHealthCard
                        metricsRow
                        quickActionsCard
                        liveRadarCard
                        latestIntelCard
                    }
                    .padding(.horizontal, overviewHorizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 150)
                }
                .refreshable { await refreshAll() }
                .dynamicTypeSize(overviewDynamicTypeSize)
                .environment(\.overviewFontScale, CGFloat(settingsStore.settings.display.fontScale))
            }
            .navigationTitle("总览")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "bell")
                    }
                    .accessibilityLabel("通知")
                    Button { showingFavorites.toggle() } label: {
                        Image(systemName: showingFavorites ? "star.fill" : "star")
                            .foregroundStyle(showingFavorites ? AppTheme.yellow : AppTheme.textPrimary)
                    }
                    .accessibilityLabel(showingFavorites ? "显示全部情报" : "只看收藏")
                }
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .task {
                if store.items.isEmpty { await store.refresh(showError: false) }
                if hotNewsStore.items.isEmpty { await hotNewsStore.refresh(settings: settingsStore.settings, showError: false) }
                await reportStore.load()
            }
        }
    }

    private var sourceHealthCard: some View {
        OverviewCard(tint: AppTheme.brandCyan) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("信息源状态", systemImage: "antenna.radiowaves.left.and.right")
                        .overviewFont(18, weight: .semibold)
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    HStack(spacing: 5) {
                        Circle().fill(failureCount == 0 ? AppTheme.green : AppTheme.yellow).frame(width: 8, height: 8)
                        Text(failureCount == 0 ? "运行正常" : "部分异常")
                            .overviewFont(12)
                            .foregroundStyle(failureCount == 0 ? AppTheme.green : AppTheme.yellow)
                    }
                }
                HStack(spacing: 5) {
                    SourceHealthItem(icon: "newspaper.fill", title: "RSS", value: "\(store.items.count)", tint: AppTheme.brandCyan)
                    SourceHealthItem(icon: "flame.fill", title: "热榜", value: "\(hotNewsStore.items.count)", tint: AppTheme.yellow)
                    SourceHealthItem(icon: "doc.text.fill", title: "报告", value: "\(reportStore.reports.count)", tint: AppTheme.brandIndigo)
                    SourceHealthItem(icon: "bell.fill", title: "未读", value: "\(unreadCount)", tint: AppTheme.brandMagenta)
                    SourceHealthItem(icon: "antenna.radiowaves.left.and.right", title: "来源", value: "\(enabledSourceCount)", tint: AppTheme.green)
                }
            }
        }
    }

    private var metricsRow: some View {
        HStack(spacing: 7) {
            OverviewMetric(value: "\(store.items.count)", label: "今日情报", icon: "waveform.path.ecg", tint: AppTheme.brandCyan)
            OverviewMetric(value: "\(favoriteCount)", label: "重要情报", icon: "eye.fill", tint: AppTheme.brandIndigo)
            OverviewMetric(value: "\(hotNewsStore.items.count)", label: "实时热点", icon: "bolt.fill", tint: AppTheme.yellow)
            OverviewMetric(value: "\(failureCount)", label: "风险预警", icon: "shield.fill", tint: AppTheme.brandMagenta)
        }
    }

    private var quickActionsCard: some View {
        OverviewCard(tint: AppTheme.brandMagenta) {
            VStack(alignment: .leading, spacing: 11) {
                OverviewSectionTitle(eyebrow: "QUICK ACTIONS", title: "快速操作", subtitle: "从总览直接开始下一步", icon: "bolt.fill", tint: AppTheme.brandMagenta)
                HStack(spacing: 7) {
                    OverviewAction(title: "刷新情报", icon: "arrow.clockwise", tint: AppTheme.brandCyan) { Task { await refreshAll() } }
                    NavigationLink { ReportCenterView() } label: { OverviewActionLabel(title: "生成报告", icon: "doc.text.badge.plus", tint: AppTheme.brandIndigo) }
                    OverviewAction(title: "监控设置", icon: "bell", tint: AppTheme.brandMagenta) { showingSettings = true }
                    NavigationLink { SettingsView() } label: { OverviewActionLabel(title: "订阅管理", icon: "star", tint: AppTheme.brandCyan) }
                }
            }
        }
    }

    private var liveRadarCard: some View {
        OverviewCard(tint: AppTheme.brandCyan) {
            VStack(alignment: .leading, spacing: 11) {
                OverviewSectionTitle(eyebrow: "LIVE SIGNALS", title: "实时热点", subtitle: "基于当前已采集的热榜数据", icon: "dot.radiowaves.left.and.right", tint: AppTheme.brandCyan)
                HStack(spacing: 12) {
                    CompactRadar(count: hotNewsStore.items.count)
                        .frame(width: 132, height: 132)
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(latestTopics) { topic in
                            HStack(spacing: 6) {
                                Circle().fill(topicColor(topic.bestRank)).frame(width: 7, height: 7)
                                Text(topic.title)
                                    .overviewFont(12, weight: .semibold)
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                Text("\(topic.bestRank)")
                                    .overviewFont(12)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                        if latestTopics.isEmpty {
                            Text("暂无热榜缓存，进入热榜页刷新")
                                .overviewFont(12)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var latestIntelCard: some View {
        OverviewCard(tint: AppTheme.brandCyan) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    OverviewSectionTitle(title: showingFavorites ? "收藏情报" : "最新情报", subtitle: "点击查看详情", icon: showingFavorites ? "star.fill" : "rectangle.text.magnifyingglass", tint: AppTheme.brandCyan)
                    Spacer()
                    Text("查看全部")
                        .overviewFont(12)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                if latestNews.isEmpty {
                    FeatureEmptyState(icon: showingFavorites ? "star" : "newspaper", title: showingFavorites ? "还没有收藏" : "暂无情报", message: "下拉刷新或调整信息源设置。")
                        .frame(maxWidth: .infinity)
                } else {
                    ForEach(latestNews) { item in
                        NavigationLink {
                            NewsDetailView(item: item).task { await store.markRead(item) }
                        } label: {
                            OverviewIntelRow(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func topicColor(_ rank: Int) -> Color {
        switch rank % 4 { case 0: return AppTheme.brandIndigo; case 1: return AppTheme.pink; case 2: return AppTheme.yellow; default: return AppTheme.brandCyan }
    }

    private func refreshAll() async {
        await store.refresh(showError: false, autoReport: false)
        await hotNewsStore.refresh(settings: settingsStore.settings, latest: true, showError: false)
        await reportStore.load()
    }
}

private struct OverviewFontScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

private extension EnvironmentValues {
    var overviewFontScale: CGFloat {
        get { self[OverviewFontScaleKey.self] }
        set { self[OverviewFontScaleKey.self] = newValue }
    }
}

private struct OverviewFontModifier: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    @Environment(\.overviewFontScale) private var scale

    func body(content: Content) -> some View {
        content.font(.system(size: size * scale, weight: weight, design: design))
    }
}

private extension View {
    func overviewFont(_ size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        modifier(OverviewFontModifier(size: size, weight: weight, design: design))
    }
}

private struct OverviewHeroCard: View {
    let date: Date
    var body: some View {
        OverviewCard(tint: AppTheme.brandCyan) {
            ZStack(alignment: .leading) {
                LinearGradient(colors: [Color.white, Color(red: 0.89, green: 0.96, blue: 1)], startPoint: .leading, endPoint: .trailing)
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("TREND RADAR")
                            .overviewFont(12, weight: .bold, design: .rounded)
                            .tracking(2.1)
                            .foregroundStyle(AppTheme.brandCyan)
                        Text("你的\n信息脉搏")
                            .overviewFont(28, weight: .semibold)
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineSpacing(2)
                        Text(date.formatted(date: .complete, time: .omitted))
                            .overviewFont(12)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    CompactRadar(count: 0)
                        .frame(width: 140, height: 126)
                        .opacity(0.72)
                        .layoutPriority(1)
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 190)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

private struct OverviewCard<Content: View>: View {
    let tint: Color
    let content: Content
    init(tint: Color, @ViewBuilder content: () -> Content) { self.tint = tint; self.content = content() }
    var body: some View {
        content
            .padding(14)
            .background(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(tint.opacity(0.25), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: tint.opacity(0.06), radius: 10, y: 4)
    }
}

private struct OverviewSectionTitle: View {
    var eyebrow: String? = nil
    let title: String
    let subtitle: String?
    let icon: String
    let tint: Color
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                if let eyebrow { Text(eyebrow).overviewFont(10, weight: .heavy).tracking(1.8).foregroundStyle(tint) }
                Text(title).overviewFont(18, weight: .semibold).foregroundStyle(AppTheme.textPrimary)
                if let subtitle { Text(subtitle).overviewFont(12).foregroundStyle(AppTheme.textSecondary) }
            }
        }
    }
}

private struct SourceHealthItem: View {
    let icon: String; let title: String; let value: String; let tint: Color
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.caption.weight(.semibold)).foregroundStyle(tint).frame(width: 29, height: 29).background(tint.opacity(0.11)).clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(title).overviewFont(10, weight: .semibold).foregroundStyle(AppTheme.textSecondary)
            Text(value).overviewFont(13, weight: .bold).foregroundStyle(AppTheme.textPrimary)
        }.frame(maxWidth: .infinity)
    }
}

private struct OverviewMetric: View {
    let value: String; let label: String; let icon: String; let tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).font(.caption.weight(.semibold)).foregroundStyle(tint)
            Text(value).overviewFont(21, weight: .bold).foregroundStyle(AppTheme.textPrimary).minimumScaleFactor(0.65)
            Text(label).overviewFont(10, weight: .medium).foregroundStyle(AppTheme.textSecondary).lineLimit(1)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(10).background(Color.white).overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(tint.opacity(0.22), lineWidth: 1)).clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

private struct OverviewAction: View {
    let title: String; let icon: String; let tint: Color; let action: () -> Void
    var body: some View { Button(action: action) { OverviewActionLabel(title: title, icon: icon, tint: tint) }.buttonStyle(.plain) }
}

private struct OverviewActionLabel: View {
    let title: String; let icon: String; let tint: Color
    var body: some View {
        HStack(spacing: 4) { Image(systemName: icon).font(.caption.weight(.semibold)); Text(title).overviewFont(10, weight: .semibold).lineLimit(1) }
            .foregroundStyle(AppTheme.textPrimary).frame(maxWidth: .infinity).padding(.vertical, 11).background(tint.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

private struct CompactRadar: View {
    let count: Int
    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                Circle().stroke(AppTheme.brandCyan.opacity(0.14 + Double(index) * 0.03), lineWidth: 1).scaleEffect(1 - CGFloat(index) * 0.19)
            }
            Circle().fill(AppTheme.brandCyan.opacity(0.10)).frame(width: 36, height: 36)
            Circle().fill(AppTheme.brandCyan).frame(width: 8, height: 8)
            Rectangle().fill(AppTheme.brandCyan.opacity(0.55)).frame(width: 110, height: 1).offset(x: 54).rotationEffect(.degrees(-24))
            Text("\(count)").font(.system(size: 12, weight: .bold, design: .default)).foregroundStyle(AppTheme.textPrimary).offset(y: 57)
        }.frame(width: 132, height: 132)
    }
}

private struct OverviewIntelRow: View {
    let item: NewsItem
    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            RoundedRectangle(cornerRadius: 3).fill(item.isRead ? AppTheme.textTertiary : AppTheme.brandCyan).frame(width: 4, height: 65)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(item.source).overviewFont(11, weight: .bold).tracking(0.5).foregroundStyle(AppTheme.brandCyan)
                    Spacer()
                    if item.isFavorite { Image(systemName: "bookmark.fill").font(.caption).foregroundStyle(AppTheme.yellow) }
                }
                Text(item.title).overviewFont(15, weight: item.isRead ? .regular : .semibold).foregroundStyle(item.isRead ? AppTheme.textSecondary : AppTheme.textPrimary).lineLimit(2)
                if let summary = TextSanitizer.plainText(item.summary), !summary.isEmpty { Text(summary).overviewFont(12).foregroundStyle(AppTheme.textSecondary).lineLimit(1) }
                Text(item.publishedAt?.relativeDescription ?? "刚刚").overviewFont(12).foregroundStyle(AppTheme.textTertiary)
            }
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 10)
        .background(AppTheme.surface.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}
