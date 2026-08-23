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
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
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
                                .font(.system(size: 22, weight: .bold, design: .rounded))
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
            .toolbarColorScheme(.light, for: .navigationBar)
            .searchable(text: $searchText, prompt: "搜索标题或来源")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingFavorites.toggle() } label: {
                        Image(systemName: showingFavorites ? "star.fill" : "star")
                            .foregroundStyle(showingFavorites ? AppTheme.yellow : .white)
                    }
                }
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Circle().fill(AppTheme.cyan).frame(width: 8, height: 8)
                        Text("TREND RADAR")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .tracking(1.5)
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { Task { await store.refresh() } } label: { Label("立即刷新", systemImage: "arrow.clockwise") }
                        Button { showingSettings = true } label: { Label("设置", systemImage: "gearshape") }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(AppTheme.textPrimary)
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
                Button("确定", role: .cancel) { store.errorMessage = nil }
            } message: { Text(store.errorMessage ?? "") }
        }
    }

    private var overviewHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("最新情报")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
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
            HStack(spacing: 10) {
                MetricPill(value: "\(store.items.count)", label: "条情报", tint: AppTheme.cyan)
                MetricPill(value: "\(store.items.filter { !$0.isRead }.count)", label: "未读", tint: AppTheme.yellow)
                MetricPill(value: "\(store.items.filter(\.isFavorite).count)", label: "收藏", tint: AppTheme.pink)
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
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(selectedSource == source ? AppTheme.background : .white.opacity(0.72))
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
        .background(AppTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(topic.strongestTrend == .new ? AppTheme.yellow.opacity(0.7) : AppTheme.cardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
    var body: some View {
        TabView {
            OverviewView()
                .tabItem { Label("总览", systemImage: "square.grid.2x2.fill") }
            DiscoverHubView()
                .tabItem { Label("发现", systemImage: "sparkles") }
            HotNewsView()
                .tabItem { Label("热榜", systemImage: "flame.fill") }
            ReportCenterView()
                .tabItem { Label("报告", systemImage: "doc.text.magnifyingglass") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
        }
        .tint(AppTheme.brandCyan)
        .preferredColorScheme(.light)
    }
}

private struct MetricPill: View {
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        HStack(spacing: 7) {
            Text(value).font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(tint)
            Text(label).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint.opacity(0.16), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct NewsCard: View {
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
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(AppTheme.cyan)
                    Spacer()
                    if item.isFavorite { Image(systemName: "star.fill").font(.caption).foregroundStyle(AppTheme.yellow) }
                }
                Text(item.title)
                    .font(.system(size: 16, weight: item.isRead ? .regular : .semibold, design: .rounded))
                    .foregroundStyle(item.isRead ? .white.opacity(0.58) : .white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                HStack(spacing: 7) {
                    Text(item.publishedAt?.relativeDescription ?? "刚刚")
                    if item.summary != nil { Text("·"); Label("已摘要", systemImage: "sparkles") }
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(AppTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(item.isRead ? AppTheme.cardBorder : AppTheme.cyan.opacity(0.25), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
            Text(isFavoriteMode ? "在新闻卡片上长按即可收藏" : "下拉刷新，开始建立你的信息雷达")
                .font(.system(size: 13, design: .rounded))
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
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

struct NewsDetailView: View {
    let item: NewsItem
    @EnvironmentObject private var store: NewsStore
    @State private var isSummarizing = false
    @State private var generatedSummary: String?

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(item.source.uppercased())
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(AppTheme.cyan)
                    Text(item.title)
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(item.publishedAt?.relativeDescription ?? "刚刚")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(AppTheme.textTertiary)

                    if let summary = generatedSummary ?? item.summary, !summary.isEmpty {
                        VStack(alignment: .leading, spacing: 11) {
                            Label("AI 摘要", systemImage: "sparkles")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.yellow)
                            Text(summary)
                                .font(.system(size: 17, weight: .medium, design: .rounded))
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineSpacing(5)
                        }
                        .padding(18)
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }

                    HStack(spacing: 10) {
                        Button {
                            isSummarizing = true
                            Task {
                                await store.summarize(item)
                                generatedSummary = store.items.first(where: { $0.id == item.id })?.summary
                                isSummarizing = false
                            }
                        } label: {
                            Label(isSummarizing ? "分析中" : "生成摘要", systemImage: "sparkles")
                        }
                        .buttonStyle(AccentButtonStyle())
                        .disabled(isSummarizing)
                        if let url = item.url {
                            Link(destination: url) { Label("阅读原文", systemImage: "arrow.up.right") }
                                .buttonStyle(OutlineButtonStyle())
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
        }
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .navigationTitle("情报详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(AppTheme.background)
            .padding(.horizontal, 15)
            .padding(.vertical, 11)
            .background(AppTheme.cyan.opacity(configuration.isPressed ? 0.65 : 1))
            .clipShape(Capsule())
    }
}

struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(AppTheme.textSecondary.opacity(configuration.isPressed ? 0.55 : 1))
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .overlay(Capsule().stroke(AppTheme.cardBorder, lineWidth: 1))
    }
}

extension Date {
    var relativeDescription: String {
        RelativeDateTimeFormatter().localizedString(for: self, relativeTo: Date())
    }
}
