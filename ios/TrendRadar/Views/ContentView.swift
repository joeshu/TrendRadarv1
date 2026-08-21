import SwiftUI

struct RadarView: View {
    @EnvironmentObject private var store: NewsStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var searchText = ""
    @State private var selectedSource = "全部"
    @State private var showingFavorites = false
    @State private var showingSettings = false

    private var sourceNames: [String] {
        ["全部"] + Array(Set(store.items.map(\.source))).sorted()
    }

    private var filteredItems: [NewsItem] {
        store.items.filter { item in
            let matchesSearch = searchText.isEmpty || item.title.localizedCaseInsensitiveContains(searchText) || item.source.localizedCaseInsensitiveContains(searchText)
            let matchesKeywords = settingsStore.settings.keywords.isEmpty || settingsStore.settings.keywords.contains { item.title.localizedCaseInsensitiveContains($0) }
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

                        if filteredItems.isEmpty {
                            EmptyNewsView(isFavoriteMode: showingFavorites)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 44)
                        } else {
                            Text(showingFavorites ? "已收藏" : "最新情报")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
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
                .refreshable { await store.refresh() }
            }
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
                            .foregroundStyle(.white)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { Task { await store.refresh() } } label: { Label("立即刷新", systemImage: "arrow.clockwise") }
                        Button { showingSettings = true } label: { Label("设置", systemImage: "gearshape") }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.white)
                    }
                }
            }
            .task { await store.requestNotifications() }
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
                    Text("早上好，观察员")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.cyan)
                    Text("今天的世界\n正在发生什么")
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineSpacing(2)
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
        .padding(.top, 8)
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
                    .foregroundStyle(AppTheme.green)
                if let lastUpdated = store.lastUpdated {
                    Text("最近更新于 \(lastUpdated, style: .relative)")
                } else {
                    Text("等待首次刷新")
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
}

struct ContentView: View {
    var body: some View {
        TabView {
            RadarView()
                .tabItem { Label("发现", systemImage: "dot.radiowaves.left.and.right") }
            FeedsView()
                .tabItem { Label("订阅", systemImage: "newspaper") }
            InsightView()
                .tabItem { Label("洞察", systemImage: "sparkles") }
            ArchiveView()
                .tabItem { Label("归档", systemImage: "archivebox") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .tint(AppTheme.cyan)
        .preferredColorScheme(.dark)
    }
}

private struct MetricPill: View {
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        HStack(spacing: 7) {
            Text(value).font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(tint)
            Text(label).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.58))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct NewsCard: View {
    let item: NewsItem

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            VStack(spacing: 4) {
                Circle().fill(item.isRead ? Color.white.opacity(0.2) : AppTheme.cyan).frame(width: 8, height: 8)
                Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 48)
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
                    .font(.system(size: 17, weight: item.isRead ? .medium : .bold, design: .rounded))
                    .foregroundStyle(item.isRead ? .white.opacity(0.58) : .white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                HStack(spacing: 7) {
                    Text(item.publishedAt?.relativeDescription ?? "刚刚")
                    if item.summary != nil { Text("·"); Label("已摘要", systemImage: "sparkles") }
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.42))
            }
        }
        .padding(16)
        .background(AppTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.06), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
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
                .foregroundStyle(.white)
            Text(isFavoriteMode ? "在新闻卡片上长按即可收藏" : "下拉刷新，开始建立你的信息雷达")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
        }
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
                        .foregroundStyle(.white)
                    Text(item.publishedAt?.relativeDescription ?? "刚刚")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))

                    if let summary = generatedSummary ?? item.summary, !summary.isEmpty {
                        VStack(alignment: .leading, spacing: 11) {
                            Label("AI 摘要", systemImage: "sparkles")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.yellow)
                            Text(summary)
                                .font(.system(size: 17, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.84))
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
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationTitle("情报详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AccentButtonStyle: ButtonStyle {
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

private struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.55 : 0.85))
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
    }
}

extension Date {
    var relativeDescription: String {
        RelativeDateTimeFormatter().localizedString(for: self, relativeTo: Date())
    }
}
