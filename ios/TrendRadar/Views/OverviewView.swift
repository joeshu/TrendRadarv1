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
        settingsStore.settings.customFeeds.filter(\.isEnabled).count
        + settingsStore.settings.platformSources.filter(\.isEnabled).count
    }
    private var latestNews: [NewsItem] { Array(store.items.filter { !showingFavorites || $0.isFavorite }.prefix(5)) }
    private var latestTopics: [HotNewsTopic] { Array(hotNewsStore.topics.prefix(4)) }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        hero
                        sourceStatus
                        metrics
                        quickActions
                        radarSummary
                        latestSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .padding(.bottom, 110)
                }
                .refreshable {
                    await store.refresh(showError: false)
                    await hotNewsStore.refresh(settings: settingsStore.settings, showError: false)
                    await reportStore.load()
                }
            }
            .navigationTitle("总览")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "bell")
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .accessibilityLabel("通知")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingFavorites.toggle() } label: {
                        Image(systemName: showingFavorites ? "star.fill" : "star")
                            .foregroundStyle(showingFavorites ? AppTheme.yellow : .white)
                    }
                    .accessibilityLabel(showingFavorites ? "显示全部情报" : "只看收藏")
                }
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .task {
                if store.items.isEmpty { await store.refresh(showError: false) }
                if hotNewsStore.items.isEmpty { await hotNewsStore.refresh(settings: settingsStore.settings, showError: false) }
            }
        }
    }

    private var hero: some View {
        PremiumPanel(tint: AppTheme.brandCyan) {
            ZStack(alignment: .bottomLeading) {
                Image("TrendRadar-ReportHero")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 148)
                    .clipped()
                    .opacity(0.56)
                LinearGradient(colors: [.clear, AppTheme.background.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 6) {
                    Text("TREND RADAR").font(.system(size: 11, weight: .bold, design: .rounded)).tracking(2).foregroundStyle(AppTheme.brandCyan)
                    Text("你的信息脉搏").font(.system(size: 29, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.textPrimary)
                    Text(Date.now.formatted(date: .complete, time: .omitted)).font(AppTheme.captionFont).foregroundStyle(AppTheme.textSecondary)
                }.padding(16)
            }
            .frame(height: 148)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var sourceStatus: some View {
        PremiumPanel(tint: AppTheme.brandCyan) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("信息源状态", systemImage: "antenna.radiowaves.left.and.right")
                        .font(AppTheme.headlineFont)
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    HStack(spacing: 5) {
                        Circle().fill(sourceStatusGood ? AppTheme.green : AppTheme.yellow).frame(width: 8, height: 8)
                        Text(sourceStatusGood ? "运行正常" : "部分异常")
                            .font(AppTheme.captionFont)
                            .foregroundStyle(sourceStatusGood ? AppTheme.green : AppTheme.yellow)
                    }
                }
                HStack(spacing: 8) {
                    SourceStatusMetric(icon: "newspaper.fill", title: "RSS", value: "\(store.items.count)", tint: AppTheme.brandCyan)
                    SourceStatusMetric(icon: "flame.fill", title: "热榜", value: "\(hotNewsStore.items.count)", tint: AppTheme.yellow)
                    SourceStatusMetric(icon: "doc.text.fill", title: "报告", value: "\(reportStore.reports.count)", tint: AppTheme.brandIndigo)
                    SourceStatusMetric(icon: "bell.fill", title: "未读", value: "\(unreadCount)", tint: AppTheme.brandMagenta)
                }
            }
        }
    }

    private var sourceStatusGood: Bool {
        store.sourceFailures.isEmpty && hotNewsStore.sourceFailures.isEmpty && !store.isRefreshing && !hotNewsStore.isRefreshing
    }


    private var metrics: some View {
        HStack(spacing: 8) {
            OverviewMetricCard(value: "\(store.items.count)", label: "今日情报", icon: "waveform.path.ecg", tint: AppTheme.brandCyan)
            OverviewMetricCard(value: "\(favoriteCount)", label: "重要情报", icon: "eye.fill", tint: AppTheme.brandIndigo)
            OverviewMetricCard(value: "\(hotNewsStore.items.count)", label: "实时热点", icon: "bolt.fill", tint: AppTheme.yellow)
            OverviewMetricCard(value: "\(store.sourceFailures.count + hotNewsStore.sourceFailures.count)", label: "风险预警", icon: "shield.fill", tint: AppTheme.brandMagenta)
        }
    }

    private var quickActions: some View {
        PremiumPanel(tint: AppTheme.brandMagenta) {
            VStack(alignment: .leading, spacing: 10) {
                PremiumSectionHeader(eyebrow: "QUICK ACTIONS", title: "快速操作", subtitle: "从总览直接开始下一步", icon: "bolt.fill", tint: AppTheme.brandMagenta)
                HStack(spacing: 8) {
                    OverviewActionButton(title: "刷新情报", icon: "arrow.clockwise", tint: AppTheme.brandCyan) {
                        Task {
                            await hotNewsStore.refresh(settings: settingsStore.settings, latest: true, showError: true)
                            await store.refresh(showError: true, autoReport: false)
                        }
                    }
                    NavigationLink {
                        ReportCenterView()
                    } label: {
                        OverviewActionLabel(title: "生成报告", icon: "doc.text.badge.plus", tint: AppTheme.brandIndigo)
                    }
                    OverviewActionButton(title: "监控设置", icon: "bell", tint: AppTheme.brandMagenta) { showingSettings = true }
                    NavigationLink {
                        SettingsView()
                    } label: {
                        OverviewActionLabel(title: "订阅管理", icon: "star", tint: AppTheme.brandCyan)
                    }
                }
            }
        }
    }

    private var radarSummary: some View {
        PremiumPanel(tint: AppTheme.brandCyan) {
            VStack(alignment: .leading, spacing: 14) {
                PremiumSectionHeader(eyebrow: "LIVE SIGNALS", title: "实时热点", subtitle: "基于当前已采集的热榜数据", icon: "dot.radiowaves.left.and.right", tint: AppTheme.brandCyan)
                HStack(spacing: 18) {
                    RadarDecoration(count: hotNewsStore.topics.count)
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(latestTopics.prefix(3)) { topic in
                            HStack(spacing: 8) {
                                Text("#\(topic.bestRank)").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.yellow)
                                Text(topic.title).font(AppTheme.captionFont).foregroundStyle(AppTheme.textPrimary).lineLimit(1)
                            }
                        }
                        if latestTopics.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("暂无热榜缓存")
                                    .font(AppTheme.headlineFont)
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text("进入热榜页刷新后，这里会显示实时信号")
                                    .font(AppTheme.captionFont)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var latestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PremiumSectionHeader(title: showingFavorites ? "收藏情报" : "最新情报", subtitle: "点击查看详情", icon: showingFavorites ? "star.fill" : "sparkles", tint: showingFavorites ? AppTheme.yellow : AppTheme.brandCyan)
                Spacer(minLength: 0)
            }
            if latestNews.isEmpty {
                FeatureEmptyState(icon: showingFavorites ? "star" : "newspaper", title: showingFavorites ? "还没有收藏" : "暂无情报", message: "下拉刷新或调整信息源设置。")
            } else {
                ForEach(latestNews) { item in
                    NavigationLink {
                        NewsDetailView(item: item).task { await store.markRead(item) }
                    } label: {
                        OverviewNewsRow(item: item)
                    }.buttonStyle(.plain)
                }
            }
        }
    }
}

private struct OverviewActionButton: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            OverviewActionLabel(title: title, icon: icon, tint: tint)
        }
        .buttonStyle(.plain)
    }
}

private struct OverviewActionLabel: View {
    let title: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(AppTheme.textPrimary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

private struct OverviewMetricCard: View {
    let value: String
    let label: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(tint.opacity(0.22), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

private struct SourceStatusMetric: View {
    let icon: String
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(title)
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct OverviewNewsRow: View {
    let item: NewsItem
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 3).fill(item.isRead ? AppTheme.textTertiary : AppTheme.brandCyan).frame(width: 4, height: 54)
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(item.source).font(.system(size: 10, weight: .bold, design: .rounded)).tracking(0.7).foregroundStyle(AppTheme.brandCyan)
                    Spacer()
                    if item.isFavorite { Image(systemName: "star.fill").font(.caption).foregroundStyle(AppTheme.yellow) }
                }
                Text(item.title)
                    .font(.system(size: 15, weight: item.isRead ? .regular : .semibold, design: .rounded))
                    .foregroundStyle(item.isRead ? AppTheme.textSecondary : AppTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                if let summary = TextSanitizer.plainText(item.summary), !summary.isEmpty {
                    Text(summary)
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                }
                Text(item.publishedAt?.relativeDescription ?? "刚刚").font(AppTheme.captionFont).foregroundStyle(AppTheme.textTertiary)
            }
        }.padding(14).background(AppTheme.card).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
    }
}
