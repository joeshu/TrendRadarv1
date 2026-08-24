import SwiftUI

struct RadarView: View {
    @EnvironmentObject private var store: NewsStore
    @EnvironmentObject private var hotNewsStore: HotNewsStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var searchText = ""
    @State private var selectedSource = "全部"
    @State private var showingFavorites = false
    @State private var showingSettings = false
    @State private var showingFeeds = false

    private var sourceNames: [String] {
        let configured = settingsStore.settings.customFeeds.filter(\.isEnabled).map(\.name)
        let cached = store.items.map(\.source)
        return ["全部"] + Array(Set(configured + cached)).sorted()
    }

    private var filteredItems: [NewsItem] {
        store.items.filter { item in
            let matchesSearch = searchText.isEmpty || item.title.localizedCaseInsensitiveContains(searchText) || item.source.localizedCaseInsensitiveContains(searchText)
            let matchesKeywords = FilterEngine(settings: settingsStore.settings).includes(item)
            let matchesSource = selectedSource == "全部" || item.source == selectedSource
            return matchesSearch && matchesKeywords && matchesSource && (!showingFavorites || item.isFavorite)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                IntelligenceScreenBackground()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: settingsStore.settings.display.cardSpacing) {
                        overviewHeader
                        refreshStatus
                        sourcePicker
                        if settingsStore.settings.display.showHotlist {
                            hotNewsSection
                        }
                        if !settingsStore.settings.display.showRSS {
                            Text("RSS 区域已在设置中隐藏")
                                .font(AppTheme.captionFont)
                                .foregroundStyle(AppTheme.textTertiary)
                                .padding(.horizontal, 20)
                        }
                        if filteredItems.isEmpty {
                            EmptyNewsView(isFavoriteMode: showingFavorites)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 44)
                        } else if settingsStore.settings.display.showRSS {
                            Text(showingFavorites ? "已收藏" : "最新情报")
                                .font(AppTheme.sectionTitleFont)
                                .foregroundStyle(AppTheme.textPrimary)
                                .padding(.horizontal, 20)

                            ForEach(filteredItems) { item in
                                NavigationLink {
                                    NewsDetailView(item: item)
                                        .task { await store.markRead(item) }
                                } label: {
                                    NewsCard(item: item)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button { Task { await store.toggleFavorite(item) } } label: {
                                        Label(item.isFavorite ? "取消收藏" : "收藏", systemImage: item.isFavorite ? "star.slash" : "star")
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                }
                .refreshable {
                    await store.refresh()
                    await hotNewsStore.refresh(settings: settingsStore.settings)
                }
            }
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .searchable(text: $searchText, prompt: "搜索标题或来源")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingFavorites.toggle() } label: {
                        ToolbarIconLabel(systemName: showingFavorites ? "star.fill" : "star", label: showingFavorites ? "显示全部情报" : "显示收藏", tint: showingFavorites ? AppTheme.yellow : AppTheme.textPrimary)
                    }
                }
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Circle().fill(AppTheme.cyan).frame(width: 8, height: 8)
                        Text("TREND RADAR")
                            .font(AppTheme.metadataFont)
                            .tracking(1.5)
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { Task { await store.refresh() } } label: { Label("立即刷新", systemImage: "arrow.clockwise") }
                        Button { showingSettings = true } label: { Label("设置", systemImage: "gearshape") }
                    } label: {
                        ToolbarIconLabel(systemName: "ellipsis.circle", label: "更多操作")
                    }
                }
            }
            .task {
                await store.requestNotifications()
                if store.items.isEmpty {
                    await store.refresh(showError: false)
                }
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .alert("提示", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                Button("重试刷新") { Task { await store.refresh() } }
                Button("确定", role: .cancel) { store.errorMessage = nil }
            } message: { Text(store.errorMessage ?? "") }
        }
    }

    private var overviewHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("最新情报")
                        .font(AppTheme.titleFont)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("来自你关注的信息源。")
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(AppTheme.cyan.opacity(0.8))
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { overviewMetrics }
                VStack(alignment: .leading, spacing: 8) { overviewMetrics }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background {
            ZStack {
                AppTheme.heroGradient
                Image("TrendRadar-ReportHero")
                    .resizable()
                    .scaledToFill()
                    .opacity(0.42)
                    .blendMode(.screen)
                    .clipped()
                LinearGradient(colors: [.clear, AppTheme.background.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(AppTheme.cyan.opacity(0.14))
                .frame(width: 118, height: 118)
                .blur(radius: 2)
                .offset(x: 34, y: -38)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private var sourcePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(sourceNames, id: \.self) { source in
                    Button { selectedSource = source } label: {
                        Text(source)
                            .font(AppTheme.captionFont.weight(.semibold))
                            .foregroundStyle(selectedSource == source ? AppTheme.background : AppTheme.textSecondary)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 9)
                            .background(selectedSource == source ? AppTheme.cyan : AppTheme.card)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private var overviewMetrics: some View {
        MetricPill(value: "\(store.items.count)", label: "条情报", tint: AppTheme.cyan)
        MetricPill(value: "\(store.items.filter { !$0.isRead }.count)", label: "未读", tint: AppTheme.yellow)
        MetricPill(value: "\(store.items.filter(\.isFavorite).count)", label: "收藏", tint: AppTheme.pink)
    }

    private var refreshStatus: some View {
        HStack(spacing: 8) {
            if store.isRefreshing {
                ProgressView()
                    .tint(AppTheme.cyan)
                Text("正在同步本地情报源")
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(store.sourceFailures.isEmpty ? AppTheme.green : AppTheme.yellow)
                if let lastUpdated = store.lastUpdated {
                    Text("最近更新于 \(lastUpdated, style: .relative)")
                } else {
                    Text("等待首次刷新")
                }
                if !store.sourceFailures.isEmpty {
                    Text("部分源失败")
                        .foregroundStyle(AppTheme.yellow)
                }
            }
            Spacer()
            Text("下拉刷新")
                .foregroundStyle(AppTheme.textTertiary)
        }
        .font(AppTheme.captionFont)
        .foregroundStyle(AppTheme.textSecondary)
        .padding(.horizontal, 20)
    }

    private var hotNewsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("实时热榜", systemImage: "flame.fill")
                    .font(AppTheme.headlineFont)
                    .foregroundStyle(AppTheme.yellow)
                Spacer()
                Button { Task { await hotNewsStore.refresh(settings: settingsStore.settings, latest: true) } } label: {
                    Image(systemName: hotNewsStore.isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                }
                .disabled(hotNewsStore.isRefreshing)
            }
            if hotNewsStore.filteredItems.isEmpty {
                FeatureEmptyState(icon: "flame", title: "暂无热榜缓存", message: "点击刷新获取 NewsNow 公开热榜数据。")
            } else {
                hotPlatformPicker
                ForEach(hotNewsStore.topics.prefix(8)) { topic in
                    NavigationLink {
                        HotNewsTrendView(topic: topic)
                    } label: {
                        RadarHotTopicCard(
                            topic: topic,
                            onFavorite: { Task { await hotNewsStore.toggleFavorite(for: topic) } },
                            onBlock: { hotNewsStore.block(topic: topic) }
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var hotPlatformPicker: some View {
        let platforms = Dictionary(hotNewsStore.items.map { ($0.platformID, $0.platformName) }, uniquingKeysWith: { first, _ in first }).sorted { $0.value < $1.value }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FeedFilterChip(title: "全部热榜", isSelected: hotNewsStore.selectedPlatformID == nil) { hotNewsStore.selectedPlatformID = nil }
                ForEach(platforms, id: \.key) { platform in
                    FeedFilterChip(title: platform.value, isSelected: hotNewsStore.selectedPlatformID == platform.key) { hotNewsStore.selectedPlatformID = platform.key }
                }
            }
        }
    }
}

private struct RadarHotTopicCard: View {
    let topic: HotNewsTopic
    let onFavorite: () -> Void
    let onBlock: () -> Void

    private var isFavorite: Bool {
        topic.items.allSatisfy(\.isFavorite)
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(topic.bestRank)")
                .font(AppTheme.rankFont)
                .foregroundStyle(topic.strongestTrend == .up ? AppTheme.green : AppTheme.pink)
                .frame(width: 50, alignment: .leading)
            VStack(alignment: .leading, spacing: 5) {
                Text(topic.title)
                    .font(AppTheme.headlineFont)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text("\(topic.platformCount) 个平台正在讨论")
                    if topic.strongestTrend == .new {
                        Text("NEW").foregroundStyle(AppTheme.yellow)
                    }
                    if let duration = topic.duration, duration >= 3600 {
                        Text("持续 \(Int(duration / 3600)) 小时")
                            .foregroundStyle(AppTheme.yellow)
                    }
                }
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textTertiary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(AppTheme.textTertiary)
        }
        .padding(14)
        .intelligenceCard(
            tint: topic.strongestTrend == .new ? AppTheme.yellow : AppTheme.brandCyan,
            cornerRadius: 16
        )
        .contextMenu {
            Button(action: onFavorite) {
                Label(isFavorite ? "取消收藏" : "收藏主题", systemImage: isFavorite ? "star.slash" : "star")
            }
            ShareLink(item: shareText) {
                Label("分享主题", systemImage: "square.and.arrow.up")
            }
            Button(role: .destructive, action: onBlock) {
                Label("屏蔽主题", systemImage: "eye.slash")
            }
        }
    }

    private var shareText: String {
        let platforms = topic.platforms.joined(separator: "、")
        return "\(topic.title)\n排名：#\(topic.bestRank)\n讨论平台：\(platforms)"
    }
}

struct ContentView: View {
    @EnvironmentObject private var store: NewsStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var reportStore: ReportStore
    @EnvironmentObject private var hotNewsStore: HotNewsStore
    @EnvironmentObject private var bootstrapper: AppBootstrapper
    @State private var selectedTab: AppTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            OverviewView()
                .tabItem { Label("今日", systemImage: "sun.max.fill") }
                .tag(AppTab.today)
            HotNewsView()
                .tabItem { Label("雷达", systemImage: "waveform.path.ecg") }
                .tag(AppTab.radar)
            FeedsView()
                .tabItem { Label("订阅", systemImage: "newspaper.fill") }
                .tag(AppTab.feeds)
            InsightView()
                .tabItem { Label("洞察", systemImage: "sparkles") }
                .tag(AppTab.insight)
            FavoritesView()
                .tabItem { Label("资料库", systemImage: "archivebox.fill") }
                .tag(AppTab.library)
        }
        .sensoryFeedback(.selection, trigger: selectedTab)
        .tint(AppTheme.electricBlue)
        .toolbar(.hidden, for: .tabBar)
        .dynamicTypeSize(.small ... .xxLarge)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CompactAppTabBar(selection: $selectedTab)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if bootstrapper.startupState.status != .normal {
                RecoveryBanner(
                    message: bootstrapper.startupState.lastFailureMessage ?? "部分服务暂不可用，当前显示本地缓存。",
                    isRetrying: bootstrapper.isStarting,
                    retry: retryStartup,
                    dismiss: bootstrapper.clearRecovery
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
    }

    private func retryStartup() {
        Task {
            await bootstrapper.retry(
                newsStore: store,
                settingsStore: settingsStore,
                reportStore: reportStore,
                hotNewsStore: hotNewsStore
            )
        }
    }
}

private enum AppTab: Hashable, CaseIterable {
    case today, radar, feeds, insight, library

    var title: String {
        switch self {
        case .today: "今日"
        case .radar: "雷达"
        case .feeds: "订阅"
        case .insight: "洞察"
        case .library: "资料库"
        }
    }

    var icon: String {
        switch self {
        case .today: "sun.max.fill"
        case .radar: "waveform.path.ecg"
        case .feeds: "newspaper.fill"
        case .insight: "sparkles"
        case .library: "archivebox.fill"
        }
    }
}

private struct CompactAppTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(AppAnimation.standard) { selection = tab }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon).font(.system(size: 18, weight: .medium))
                        Text(tab.title).font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(selection == tab ? AppTheme.electricBlue : AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(selection == tab ? AppTheme.electricBlue.opacity(0.13) : Color.clear, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(4)
        .background(AppTheme.card.opacity(0.98), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(AppTheme.cardBorder.opacity(0.65), lineWidth: 1))
        .shadow(color: .black.opacity(0.2), radius: 10, y: 3)
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }
}

private struct MetricPill: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 3) { metricContent }
            } else {
                HStack(spacing: 7) { metricContent }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .intelligenceCard(tint: tint, cornerRadius: 12)
    }

    @ViewBuilder private var metricContent: some View {
        Text(value).font(AppTheme.numericFont).foregroundStyle(tint)
        Text(label).font(AppTheme.metadataFont).foregroundStyle(AppTheme.textSecondary)
    }
}

private struct NewsCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let item: NewsItem

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            VStack(spacing: 4) {
                Circle().fill(item.isRead ? AppTheme.textTertiary.opacity(0.45) : AppTheme.cyan).frame(width: 8, height: 8)
                Rectangle().fill(AppTheme.cardBorder).frame(width: 1, height: 48)
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(item.source.uppercased())
                        .font(AppTheme.metadataFont)
                        .tracking(1)
                        .foregroundStyle(AppTheme.cyan)
                    Spacer()
                    if item.isFavorite { Image(systemName: "star.fill").font(.caption).foregroundStyle(AppTheme.yellow) }
                }
                Text(item.translatedTitle ?? item.title)
                    .font(item.isRead ? AppTheme.bodyFont : AppTheme.cardTitleFont)
                    .foregroundStyle(item.isRead ? AppTheme.textSecondary : AppTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                if item.translatedTitle != nil {
                    Label("已翻译", systemImage: "character.book.closed")
                        .font(AppTheme.metadataFont)
                        .foregroundStyle(AppTheme.brandIndigo)
                }
                HStack(spacing: 7) {
                    Text(item.publishedAt?.relativeDescription ?? "刚刚")
                    if item.summary != nil { Text("·"); Label("已摘要", systemImage: "sparkles") }
                }
                .font(AppTheme.metadataFont)
                .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .intelligenceCard(tint: item.isRead ? AppTheme.brandIndigo : AppTheme.cyan, cornerRadius: 14)
    }
}

private struct EmptyNewsView: View {
    let isFavoriteMode: Bool

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: isFavoriteMode ? "star" : "dot.radiowaves.left.and.right")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(AppTheme.cyan)
            Text(isFavoriteMode ? "还没有收藏" : "等待第一批情报")
                .font(AppTheme.sectionTitleFont)
                .foregroundStyle(AppTheme.textPrimary)
            Text(isFavoriteMode ? "在新闻卡片上长按即可收藏" : "下拉刷新，开始建立你的信息雷达")
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textTertiary)
        }
    }
}

private struct HotNewsCard: View {
    let item: HotNewsItem

    var body: some View {
        HStack(spacing: 12) {
            Text("\(item.rank)")
                .font(AppTheme.rankFont)
                .foregroundStyle(item.trend == .up ? AppTheme.red : AppTheme.yellow)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(item.platformName)
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.yellow)
                    Spacer()
                    Label(item.trend.rawValue, systemImage: item.trend == .up ? "arrow.up" : item.trend == .down ? "arrow.down" : "minus")
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textTertiary)
                }
                Text(item.title)
                    .font(AppTheme.headlineFont)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .intelligenceCard(tint: item.trend == .up ? AppTheme.green : AppTheme.yellow, cornerRadius: 15)
    }
}

struct NewsDetailView: View {
    let item: NewsItem
    @EnvironmentObject private var store: NewsStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var isSummarizing = false
    @State private var generatedSummary: String?
    @State private var translatedTitle: String?
    @State private var isTranslating = false
    @State private var isFavorite = false
    @State private var actionFeedback: ActionFeedback?

    private var intelligenceTags: [String] {
        let text = [item.title, item.summary ?? "", item.body ?? ""].joined(separator: " ")
        let matched = settingsStore.settings.keywords.filter { keyword in
            let clean = keyword.trimmingCharacters(in: CharacterSet(charactersIn: "+!"))
            return !clean.isEmpty && text.localizedCaseInsensitiveContains(clean)
        }
        return Array(([item.source] + matched).prefix(6))
    }

    var body: some View {
        ZStack {
            IntelligenceScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageVisualBanner(assetName: "TrendRadar-ReadingHero")
                    HStack(spacing: 8) {
                        Circle().fill(AppTheme.cyan).frame(width: 8, height: 8)
                        Text(item.source).font(AppTheme.headlineFont).foregroundStyle(AppTheme.cyan)
                        Spacer()
                        Text(item.publishedAt?.relativeDescription ?? "刚刚").font(AppTheme.captionFont).foregroundStyle(AppTheme.textTertiary)
                    }
                    Text(translatedTitle ?? item.translatedTitle ?? item.title)
                        .font(AppTheme.titleFont)
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineSpacing(3)
                    if !intelligenceTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 7) { ForEach(intelligenceTags, id: \.self) { PremiumTag(text: $0, tint: AppTheme.brandIndigo) } }
                        }.accessibilityLabel("情报标签：\(intelligenceTags.joined(separator: "、"))")
                    }
                    if translatedTitle != nil || item.translatedTitle != nil {
                        VStack(alignment: .leading, spacing: 5) {
                            Label("原文标题", systemImage: "text.quote")
                                .font(AppTheme.metadataFont)
                                .foregroundStyle(AppTheme.brandIndigo)
                            Text(item.title).font(AppTheme.captionFont).foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    if let summary = generatedSummary ?? item.summary, !summary.isEmpty {
                        VStack(alignment: .leading, spacing: 11) {
                            Label("AI 摘要", systemImage: "sparkles")
                                .font(AppTheme.headlineFont)
                                .foregroundStyle(AppTheme.yellow)
                            Text(summary)
                                .font(AppTheme.readingFont)
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineSpacing(6)
                        }
                        .padding(18)
                        .intelligenceCard(tint: AppTheme.yellow, cornerRadius: 18)
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) { detailActions }
                        VStack(alignment: .leading, spacing: 10) { detailActions }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .navigationTitle("情报详情")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let current = store.items.first(where: { $0.id == item.id })
            translatedTitle = current?.translatedTitle ?? item.translatedTitle
            isFavorite = current?.isFavorite ?? item.isFavorite
        }
        .overlay(alignment: .top) {
            if let actionFeedback {
                ActionFeedbackBanner(feedback: actionFeedback) { self.actionFeedback = nil }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
        }
        .animation(AppAnimation.standard, value: actionFeedback)
        .sensoryFeedback(.success, trigger: actionFeedback?.kind == .success)
        .sensoryFeedback(.error, trigger: actionFeedback?.kind == .failure)
    }

    @ViewBuilder
    private var detailActions: some View {
        Button {
            isSummarizing = true
            actionFeedback = .progress("正在生成本机情报摘要")
            store.errorMessage = nil
            Task {
                await store.summarize(item)
                generatedSummary = store.items.first(where: { $0.id == item.id })?.summary
                isSummarizing = false
                actionFeedback = store.errorMessage.map { .failure($0) } ?? .success("摘要已生成并保存到本机")
            }
        } label: { Label(isSummarizing ? "分析中" : "生成摘要", systemImage: "sparkles") }
        .buttonStyle(AccentButtonStyle())
        .disabled(isSummarizing)
        Button {
            Task {
                await store.toggleFavorite(item)
                isFavorite.toggle()
                actionFeedback = .success(isFavorite ? "已加入资料库" : "已取消收藏")
            }
        } label: { Label(isFavorite ? "已收藏" : "收藏", systemImage: isFavorite ? "star.fill" : "star") }
            .buttonStyle(OutlineButtonStyle())
        ShareLink(item: item.url?.absoluteString ?? item.title, subject: Text(item.title), message: Text(item.summary ?? item.title)) {
            Label("分享", systemImage: "square.and.arrow.up")
        }.buttonStyle(OutlineButtonStyle())
        if settingsStore.settings.aiTranslation.enabled && settingsStore.settings.aiTranslation.translateRSS {
            Button {
                isTranslating = true
                actionFeedback = .progress("正在翻译标题")
                store.errorMessage = nil
                Task {
                    translatedTitle = await store.translateTitle(item)
                    isTranslating = false
                    actionFeedback = translatedTitle == nil
                        ? .failure(store.errorMessage ?? "标题翻译失败，请检查 AI 设置")
                        : .success("译文已保存到本机")
                }
            } label: {
                Label(isTranslating ? "翻译中" : (translatedTitle == nil && item.translatedTitle == nil ? "翻译标题" : "重新翻译"), systemImage: "character.book.closed")
            }
            .buttonStyle(OutlineButtonStyle())
            .disabled(isTranslating)
        }
        if let url = item.url {
            Link(destination: url) { Label("阅读原文", systemImage: "arrow.up.right") }
                .buttonStyle(OutlineButtonStyle())
        }
    }
}

struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.headlineFont)
            .foregroundStyle(.white)
            .padding(.horizontal, 17)
            .frame(minHeight: 44)
            .background(AppTheme.accentGradient.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .shadow(color: AppTheme.electricBlue.opacity(configuration.isPressed ? 0 : 0.18), radius: 10, y: 5)
    }
}

struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.headlineFont)
            .foregroundStyle(AppTheme.textSecondary.opacity(configuration.isPressed ? 0.55 : 1))
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(AppTheme.surface.opacity(configuration.isPressed ? 0.42 : 0.70))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(AppTheme.electricBlue.opacity(0.38), lineWidth: 1))
    }
}

extension Date {
    var relativeDescription: String {
        RelativeDateTimeFormatter().localizedString(for: self, relativeTo: Date())
    }
}
