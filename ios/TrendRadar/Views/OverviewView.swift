import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var store: NewsStore
    @EnvironmentObject private var hotNewsStore: HotNewsStore
    @EnvironmentObject private var reportStore: ReportStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var showingFavorites = false

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
                        statusLine
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
                    Button { showingFavorites.toggle() } label: {
                        Image(systemName: showingFavorites ? "star.fill" : "star")
                            .foregroundStyle(showingFavorites ? AppTheme.yellow : .white)
                    }
                    .accessibilityLabel(showingFavorites ? "显示全部情报" : "只看收藏")
                }
            }
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
                    .frame(height: 178)
                    .clipped()
                    .opacity(0.56)
                LinearGradient(colors: [.clear, AppTheme.background.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 6) {
                    Text("TREND RADAR").font(.system(size: 11, weight: .bold, design: .rounded)).tracking(2).foregroundStyle(AppTheme.brandCyan)
                    Text("你的信息脉搏").font(.system(size: 29, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.textPrimary)
                    Text(Date.now.formatted(date: .complete, time: .omitted)).font(AppTheme.captionFont).foregroundStyle(AppTheme.textSecondary)
                }.padding(16)
            }.frame(height: 178).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var statusLine: some View {
        PremiumStatusLine(
            title: store.isRefreshing || hotNewsStore.isRefreshing ? "正在同步信息源" : "信息源状态",
            detail: store.sourceFailures.isEmpty && hotNewsStore.sourceFailures.isEmpty ? (store.lastUpdated?.relativeDescription ?? "等待首次刷新") : "部分来源异常",
            isGood: !store.isRefreshing && store.sourceFailures.isEmpty && hotNewsStore.sourceFailures.isEmpty
        )
        .padding(.horizontal, 4)
    }

    private var metrics: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            PremiumMetricCard(value: "\(store.items.count)", label: "RSS 情报", icon: "newspaper.fill", tint: AppTheme.brandCyan)
            PremiumMetricCard(value: "\(hotNewsStore.items.count)", label: "热榜条目", icon: "flame.fill", tint: AppTheme.yellow)
            PremiumMetricCard(value: "\(enabledSourceCount)", label: "启用来源", icon: "antenna.radiowaves.left.and.right", tint: AppTheme.brandIndigo)
            PremiumMetricCard(value: "\(unreadCount) · \(favoriteCount)", label: "未读 · 收藏", icon: "bookmark.fill", tint: AppTheme.brandMagenta)
        }
    }

    private var quickActions: some View {
        PremiumPanel(tint: AppTheme.brandMagenta) {
            VStack(alignment: .leading, spacing: 10) {
                PremiumSectionHeader(eyebrow: "QUICK ACTIONS", title: "快速操作", subtitle: "从总览直接开始下一步", icon: "bolt.fill", tint: AppTheme.brandMagenta)
                HStack(spacing: 10) {
                    Button {
                        Task {
                            await hotNewsStore.refresh(settings: settingsStore.settings, latest: true, showError: true)
                            await store.refresh(showError: true, autoReport: false)
                        }
                    } label: {
                        Label("刷新情报", systemImage: "arrow.clockwise")
                            .font(AppTheme.captionFont)
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(AppTheme.brandCyan.opacity(0.18))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    NavigationLink {
                        ReportCenterView()
                    } label: {
                        Label("查看报告", systemImage: "doc.text.magnifyingglass")
                            .font(AppTheme.captionFont)
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(AppTheme.brandMagenta.opacity(0.18))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                        if latestTopics.isEmpty { Text("暂无热榜缓存，进入热榜页刷新").font(AppTheme.captionFont).foregroundStyle(AppTheme.textSecondary) }
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
