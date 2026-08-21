import SwiftUI

struct FeedsView: View {
    @EnvironmentObject private var store: NewsStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var selectedFeedID: String?
    @State private var showingFeedInfo = false

    private var enabledFeeds: [ConfigFeed] {
        settingsStore.settings.customFeeds.filter(\.isEnabled)
    }

    private var feedItems: [NewsItem] {
        guard let selectedFeedID else { return store.items }
        guard let feed = settingsStore.settings.customFeeds.first(where: { $0.id == selectedFeedID }) else { return [] }
        return store.items.filter { $0.source == feed.name }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        pageHeader
                        feedPicker
                        if feedItems.isEmpty {
                            FeatureEmptyState(icon: "newspaper", title: "暂无订阅内容", message: "启用 RSS 源后，下拉刷新获取订阅文章。")
                                .frame(maxWidth: .infinity)
                                .padding(.top, 32)
                        } else {
                            ForEach(feedItems) { item in
                                NavigationLink {
                                    NewsDetailView(item: item)
                                        .task { await store.markRead(item) }
                                } label: {
                                    CompactFeedCard(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(20)
                }
                .refreshable { await store.refresh() }
            }
            .navigationTitle("订阅")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingFeedInfo = true } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .sheet(isPresented: $showingFeedInfo) {
                FeedInfoSheet(feedCount: enabledFeeds.count)
            }
        }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FEED NETWORK")
                .font(AppTheme.captionFont)
                .tracking(1.6)
                .foregroundStyle(AppTheme.cyan)
            Text("你的信息源")
                .font(AppTheme.titleFont)
                .foregroundStyle(.white)
            Text("把分散的订阅，收束成一条安静的信息流。")
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var feedPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FeedFilterChip(title: "全部", isSelected: selectedFeedID == nil) { selectedFeedID = nil }
                ForEach(enabledFeeds) { feed in
                    FeedFilterChip(title: feed.name, isSelected: selectedFeedID == feed.id) { selectedFeedID = feed.id }
                }
            }
        }
    }
}

struct InsightView: View {
    @EnvironmentObject private var store: NewsStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var showingSettings = false

    private var keywordMatches: [NewsItem] {
        guard !settingsStore.settings.keywords.isEmpty else { return store.items }
        return store.items.filter { item in
            settingsStore.settings.keywords.contains { item.title.localizedCaseInsensitiveContains($0) }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        insightHeader
                        signalCard
                        keywordCard
                        aiCard
                    }
                    .padding(20)
                }
            }
            .navigationTitle("洞察")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: { Image(systemName: "slider.horizontal.3") }
                }
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
        }
    }

    private var insightHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("INTELLIGENCE")
                .font(AppTheme.captionFont)
                .tracking(1.6)
                .foregroundStyle(AppTheme.yellow)
            Text("今天值得关注什么")
                .font(AppTheme.titleFont)
                .foregroundStyle(.white)
            Text("本地统计来自当前已抓取的新闻，不替代真实 AI 研判。")
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var signalCard: some View {
        InsightPanel(title: "情报脉搏", icon: "waveform.path.ecg", tint: AppTheme.cyan) {
            HStack(spacing: 12) {
                InsightMetric(value: "\(store.items.count)", label: "已采集", tint: AppTheme.cyan)
                InsightMetric(value: "\(keywordMatches.count)", label: "关注命中", tint: AppTheme.yellow)
                InsightMetric(value: "\(store.items.filter { !$0.isRead }.count)", label: "待阅读", tint: AppTheme.pink)
            }
        }
    }

    private var keywordCard: some View {
        InsightPanel(title: "关注主题", icon: "tag", tint: AppTheme.yellow) {
            if settingsStore.settings.keywords.isEmpty {
                Text("尚未配置关键词，当前展示全部订阅内容。")
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                FlowLayout(items: settingsStore.settings.keywords)
            }
        }
    }

    private var aiCard: some View {
        InsightPanel(title: "AI 洞察", icon: "sparkles", tint: AppTheme.cyan) {
            VStack(alignment: .leading, spacing: 10) {
                Text(settingsStore.settings.ai.enabled ? "AI 分析已启用" : "AI 分析未启用")
                    .font(AppTheme.headlineFont)
                    .foregroundStyle(.white)
                Text(settingsStore.settings.ai.enabled ? "打开新闻详情即可按需生成摘要。" : "在设置中启用 AI，并配置 API Base URL 与 Key。")
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }
}

struct ArchiveView: View {
    @EnvironmentObject private var store: NewsStore
    @State private var showingFavorites = false

    private var items: [NewsItem] {
        showingFavorites ? store.items.filter(\.isFavorite) : store.items
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        archiveHeader
                        archiveSwitch
                        if items.isEmpty {
                            FeatureEmptyState(icon: showingFavorites ? "star" : "archivebox", title: showingFavorites ? "还没有收藏" : "归档为空", message: "在情报流中收藏重要内容，它们会出现在这里。")
                                .frame(maxWidth: .infinity)
                                .padding(.top, 32)
                        } else {
                            ForEach(items) { item in
                                NavigationLink {
                                    NewsDetailView(item: item)
                                } label: {
                                    CompactFeedCard(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("归档")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var archiveHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ARCHIVE")
                .font(AppTheme.captionFont)
                .tracking(1.6)
                .foregroundStyle(AppTheme.pink)
            Text("留下真正重要的信号")
                .font(AppTheme.titleFont)
                .foregroundStyle(.white)
            Text("历史报告中心将在报告存储接入后与这里合并。")
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var archiveSwitch: some View {
        HStack(spacing: 8) {
            FeedFilterChip(title: "全部情报", isSelected: !showingFavorites) { showingFavorites = false }
            FeedFilterChip(title: "我的收藏", isSelected: showingFavorites) { showingFavorites = true }
        }
    }
}

private struct CompactFeedCard: View {
    let item: NewsItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(item.isRead ? AppTheme.textTertiary : AppTheme.cyan)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(item.source.uppercased())
                        .font(AppTheme.captionFont)
                        .tracking(0.8)
                        .foregroundStyle(AppTheme.cyan)
                    Spacer()
                    if item.isFavorite { Image(systemName: "star.fill").foregroundStyle(AppTheme.yellow) }
                }
                Text(item.title)
                    .font(AppTheme.headlineFont)
                    .foregroundStyle(item.isRead ? AppTheme.textSecondary : .white)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    Text(item.publishedAt?.relativeDescription ?? "刚刚")
                    if item.summary != nil { Label("已摘要", systemImage: "sparkles") }
                }
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .padding(16)
        .background(AppTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06)))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct FeedFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTheme.captionFont)
                .foregroundStyle(isSelected ? AppTheme.background : AppTheme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(isSelected ? AppTheme.cyan : AppTheme.card)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct InsightPanel<Content: View>: View {
    let title: String
    let icon: String
    let tint: Color
    let content: Content

    init(title: String, icon: String, tint: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(AppTheme.headlineFont)
                .foregroundStyle(tint)
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

private struct InsightMetric: View {
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(AppTheme.rankFont).foregroundStyle(tint)
            Text(label).font(AppTheme.captionFont).foregroundStyle(AppTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FlowLayout: View {
    let items: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.background)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(AppTheme.yellow)
                        .clipShape(Capsule())
                }
            }
        }
    }
}

private struct FeatureEmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(AppTheme.cyan)
            Text(title)
                .font(AppTheme.headlineFont)
                .foregroundStyle(.white)
            Text(message)
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(26)
    }
}

private struct FeedInfoSheet: View {
    let feedCount: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(AppTheme.cyan)
                Text("已启用 \(feedCount) 个订阅源")
                    .font(AppTheme.titleFont)
                    .foregroundStyle(.white)
                Text("RSS 与 Atom 内容会在刷新时并发抓取，并保存到本地情报库。")
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Spacer()
            }
            .padding(.top, 48)
            .frame(maxWidth: .infinity)
            .background(AppTheme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
        .tint(AppTheme.cyan)
    }
}
