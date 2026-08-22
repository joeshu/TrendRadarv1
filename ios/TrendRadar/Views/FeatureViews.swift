import SwiftUI
import Charts

struct FeedsView: View {
    @EnvironmentObject private var store: NewsStore
    @EnvironmentObject private var hotNewsStore: HotNewsStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var selectedFeedID: String?
    @State private var showingFeedInfo = false
    @State private var showingSourceManager = false
    @State private var showingUnreadOnly = false

    private var enabledFeeds: [ConfigFeed] {
        settingsStore.settings.customFeeds.filter(\.isEnabled)
    }

    private var feedItems: [NewsItem] {
        let filterEngine = FilterEngine(settings: settingsStore.settings)
        let filtered = store.items.filter { filterEngine.includes($0) && (!showingUnreadOnly || !$0.isRead) }
        guard let selectedFeedID else { return filtered }
        guard let feed = settingsStore.settings.customFeeds.first(where: { $0.id == selectedFeedID }) else { return [] }
        return filtered.filter { $0.source == feed.name }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        feedIntro
                        sourceSummary
                        feedPicker
                        HStack {
                            Toggle("仅未读", isOn: $showingUnreadOnly)
                            Spacer()
                            Button("全部已读") { Task { await store.markAllRead() } }
                                .font(AppTheme.captionFont)
                                .foregroundStyle(AppTheme.cyan)
                        }
                        if enabledFeeds.isEmpty {
                            FeatureEmptyState(icon: "antenna.radiowaves.left.and.right.slash", title: "还没有启用订阅源", message: "在设置中启用 RSS 源，再回来刷新你的信息流。")
                                .frame(maxWidth: .infinity)
                                .padding(.top, 32)
                        } else if feedItems.isEmpty {
                            FeatureEmptyState(icon: "newspaper", title: "暂无订阅内容", message: "启用 RSS 源后，下拉刷新获取订阅文章。")
                                .frame(maxWidth: .infinity)
                                .padding(.top, 32)
                        } else {
                            ForEach(feedItems) { item in
                                NavigationLink {
                                    FeedReaderView(item: item)
                                        .task { await store.markRead(item) }
                                } label: {
                                    CompactFeedCard(item: item)
                                }
                                .buttonStyle(.plain)
                                .overlay(alignment: .topTrailing) {
                                    if relatedTopic(for: item) != nil {
                                        Text("关联热榜")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(AppTheme.yellow)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 4)
                                            .background(AppTheme.yellow.opacity(0.14))
                                            .clipShape(Capsule())
                                            .padding(8)
                                    }
                                }
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
                    Button { showingSourceManager = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("管理信息源")
                }
            }
            .sheet(isPresented: $showingFeedInfo) {
                FeedInfoSheet(feedCount: enabledFeeds.count)
            }
            .sheet(isPresented: $showingSourceManager) {
                SubscriptionSourceManager()
            }
        }
    }

    private func relatedTopic(for item: NewsItem) -> HotNewsTopic? {
        let key = TopicDeduplicator().topicKey(for: item.title)
        return hotNewsStore.topics.first { topic in
            topic.id == key || topic.items.contains { item.title.localizedCaseInsensitiveContains($0.title) }
        }
    }

    private var sourceSummary: some View {
        HStack(spacing: 12) {
            FeedSummaryMetric(value: "\(enabledFeeds.count)", label: "RSS 源", tint: AppTheme.cyan)
            FeedSummaryMetric(value: "\(settingsStore.settings.platformSources.filter(\.isEnabled).count)", label: "热榜平台", tint: AppTheme.pink)
            FeedSummaryMetric(value: "\(feedItems.filter { !$0.isRead }.count)", label: "待阅读", tint: AppTheme.yellow)
        }
        .padding(16)
        .background(AppTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var feedIntro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("管理信息源")
                .font(AppTheme.headlineFont)
                .foregroundStyle(.white)
            Text("选择来源，阅读对应的订阅内容。")
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(16)
        .background(AppTheme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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

    private var feedSummary: some View {
        HStack(spacing: 12) {
            FeedSummaryMetric(value: "\(enabledFeeds.count)", label: "启用源", tint: AppTheme.cyan)
            FeedSummaryMetric(value: "\(feedItems.count)", label: selectedFeedID == nil ? "全部文章" : "当前源文章", tint: AppTheme.yellow)
            FeedSummaryMetric(value: "\(feedItems.filter { !$0.isRead }.count)", label: "待阅读", tint: AppTheme.pink)
        }
        .padding(.vertical, 4)
    }
}

struct SubscriptionSourceManager: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var newsStore: NewsStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingFeedEditor = false
    @State private var editingFeed: ConfigFeed?

    var body: some View {
        NavigationStack {
            Form {
                Section("RSS 订阅") {
                    Toggle("启用 RSS", isOn: $settingsStore.settings.rssEnabled)
                    Toggle("只保留最近文章", isOn: $settingsStore.settings.rssFreshnessEnabled)
                    if settingsStore.settings.rssFreshnessEnabled {
                        Stepper("文章保留 \(settingsStore.settings.rssMaxAgeDays) 天", value: $settingsStore.settings.rssMaxAgeDays, in: 0...30)
                    }
                    ForEach($settingsStore.settings.customFeeds) { $feed in
                        Button {
                            editingFeed = feed
                            showingFeedEditor = true
                        } label: {
                            HStack {
                                Image(systemName: feed.isEnabled ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(feed.isEnabled ? AppTheme.cyan : AppTheme.textTertiary)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(feed.name).foregroundStyle(.white)
                                    Text(feed.url).font(AppTheme.captionFont).foregroundStyle(AppTheme.textTertiary).lineLimit(1)
                                    if let health = newsStore.feedHealth[feed.id], health.shouldShowWarning {
                                        Text("连续失败 \(health.consecutiveFailures) 次：\(health.lastError ?? "请检查来源")")
                                            .font(.caption2)
                                            .foregroundStyle(AppTheme.yellow)
                                    }
                                }
                            }
                        }
                    }
                    Button("添加 RSS 源") {
                        editingFeed = nil
                        showingFeedEditor = true
                    }
                }
                Section("热榜平台") {
                    Toggle("启用热榜", isOn: $settingsStore.settings.platformsEnabled)
                    ForEach($settingsStore.settings.platformSources) { $source in
                        Toggle(source.name, isOn: $source.isEnabled)
                    }
                    TextField("热榜 API 地址", text: $settingsStore.settings.platformAPIURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("填写基础地址，例如 https://newsnow.vercel.app/api。应用会按平台 ID 请求 /s?id=平台ID；保持默认地址即可。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("信息源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
            .sheet(isPresented: $showingFeedEditor) {
                FeedEditorView(feed: editingFeed) { feed in
                    if let index = settingsStore.settings.customFeeds.firstIndex(where: { $0.id == feed.id }) {
                        settingsStore.settings.customFeeds[index] = feed
                    } else {
                        settingsStore.settings.customFeeds.append(feed)
                    }
                    editingFeed = nil
                }
            }
            .preferredColorScheme(.dark)
            .tint(AppTheme.cyan)
        }
    }

}

struct FeedReaderView: View {
    let item: NewsItem
    @EnvironmentObject private var store: NewsStore

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(item.source.uppercased())
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.cyan)
                    Text(item.title)
                        .font(AppTheme.titleFont)
                        .foregroundStyle(.white)
                    if let author = item.author, !author.isEmpty {
                        Text(author).font(AppTheme.captionFont).foregroundStyle(AppTheme.textSecondary)
                    }
                    Text(item.body ?? item.summary ?? "暂无正文缓存")
                        .font(.system(size: 18, weight: .regular, design: .serif))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineSpacing(7)
                    if let url = item.url {
                        Link(destination: url) {
                            Label("阅读原文", systemImage: "arrow.up.right")
                        }
                        .buttonStyle(OutlineButtonStyle())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
        }
        .navigationTitle("阅读器")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.markRead(item) }
    }
}

struct InsightView: View {
    @EnvironmentObject private var store: NewsStore
    @EnvironmentObject private var hotNewsStore: HotNewsStore
    @EnvironmentObject private var reportStore: ReportStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var showingSettings = false
    @State private var selectedWindow: InsightTimeWindow = .current
    @State private var queryText = ""
    @State private var queryResult: InsightQueryResult?
    @State private var isQuerying = false
    @State private var isGenerating = false
    @State private var latestAnalysis: ReportAIAnalysis?

    private var keywordMatches: [NewsItem] {
        let filterEngine = FilterEngine(settings: settingsStore.settings)
        return store.items.filter { filterEngine.includes($0) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        insightHeader
                        insightWindowPicker
                        signalCard
                        sentimentCard
                        keywordCard
                        hotNewsInsightCard
                        anomalyCard
                        aiCard
                        queryCard
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
            .task {
                await reportStore.load()
                await loadLatestAnalysis()
            }
        }
    }

    private func loadLatestAnalysis() async {
        guard let latest = reportStore.reports.first else {
            latestAnalysis = nil
            return
        }
        latestAnalysis = await reportStore.detail(id: latest.id)?.aiAnalysis
    }

    private var insightHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今天值得关注什么")
                .font(AppTheme.headlineFont)
                .foregroundStyle(.white)
            Text("基于当前已抓取的新闻。")
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var windowItems: [NewsItem] {
        store.items.filter { selectedWindow.includes($0.publishedAt) }
    }

    private var windowHotlistItems: [HotNewsItem] {
        hotNewsStore.items.filter { selectedWindow.includes($0.publishedAt) }
    }

    private var insightWindowPicker: some View {
        Picker("分析范围", selection: $selectedWindow) {
            ForEach(InsightTimeWindow.allCases, id: \.self) { window in
                Text(window.title).tag(window)
            }
        }
        .pickerStyle(.segmented)
    }

    private var signalCard: some View {
        InsightPanel(title: "情报脉搏", icon: "waveform.path.ecg", tint: AppTheme.cyan) {
            HStack(spacing: 12) {
                InsightMetric(value: "\(windowItems.count + windowHotlistItems.count)", label: "分析样本", tint: AppTheme.cyan)
                InsightMetric(value: "\(keywordMatches.count)", label: "关注命中", tint: AppTheme.yellow)
                InsightMetric(value: "\(windowItems.filter { !$0.isRead }.count)", label: "待阅读", tint: AppTheme.pink)
            }
        }
    }

    private var sentimentCard: some View {
        let sentiment = localSentiment
        return InsightPanel(title: "情绪面板", icon: "gauge.with.dots.needle.67percent", tint: AppTheme.pink) {
            if sentiment.isComputed {
                HStack(spacing: 12) {
                    InsightMetric(value: "\(Int(sentiment.positive * 100))%", label: "正面", tint: AppTheme.green)
                    InsightMetric(value: "\(Int(sentiment.neutral * 100))%", label: "中立", tint: AppTheme.textSecondary)
                    InsightMetric(value: "\(Int(sentiment.negative * 100))%", label: "负面", tint: AppTheme.red)
                }
                Text("样本 \(sentiment.sampleCount) 条，指数 \(sentiment.score >= 0 ? "+" : "")\(sentiment.score, specifier: "%.2f")")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textTertiary)
            } else {
                Text("当前范围尚未完成情绪计算。生成 AI 报告后会显示模型结果。")
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private var localSentiment: InsightSentiment {
        guard let analysis = latestAnalysis,
              let positive = analysis.sentimentPositive,
              let neutral = analysis.sentimentNeutral,
              let negative = analysis.sentimentNegative,
              analysis.hasContent else {
            return InsightSentiment(positive: 0, neutral: 0, negative: 0, sampleCount: 0)
        }
        let total = max(1, windowItems.count + windowHotlistItems.count)
        return InsightSentiment(positive: positive, neutral: neutral, negative: negative, sampleCount: total)
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
                if settingsStore.settings.ai.enabled {
                    Button {
                        isGenerating = true
                        Task {
                            await reportStore.generate(type: reportType, settings: settingsStore.settings, items: windowItems, hotlistItems: windowHotlistItems, diagnostics: reportStore.diagnostics(news: store, hotNews: hotNewsStore))
                            await loadLatestAnalysis()
                            isGenerating = false
                        }
                    } label: {
                        Label(isGenerating ? "正在生成" : "生成 \(selectedWindow.title) 报告", systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(AccentButtonStyle())
                    .disabled(isGenerating)
                    Label("报告生成时会按结构化 JSON 保存情绪比例、弱信号和策略建议。", systemImage: "info.circle")
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
        }
    }

    private var reportType: ReportType {
        switch selectedWindow {
        case .current: return .current
        case .daily: return .daily
        case .incremental: return .incremental
        }
    }

    private var queryCard: some View {
        InsightPanel(title: "自然语言查询", icon: "bubble.left.and.text.bubble.right", tint: AppTheme.cyan) {
            TextField("例如：最近一周科技圈有什么大事？", text: $queryText, axis: .vertical)
            Button {
                let question = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !question.isEmpty else { return }
                isQuerying = true
                Task {
                    defer { isQuerying = false }
                    do {
                        queryResult = try await AIService().query(question: question, hotlistItems: windowHotlistItems, rssItems: windowItems, settings: settingsStore.settings)
                    } catch {
                        queryResult = InsightQueryResult(answer: "查询失败：\(error.localizedDescription)", citations: [], createdAt: Date())
                    }
                }
            } label: {
                Label(isQuerying ? "查询中" : "查询本地情报", systemImage: "arrow.up.circle")
            }
            .buttonStyle(OutlineButtonStyle())
            .disabled(isQuerying)
            if let result = queryResult {
                Text(result.answer)
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(.white)
                ForEach(result.citations) { citation in
                    if let url = citation.url {
                        Link("引用：\(citation.source) · \(citation.title)", destination: url)
                            .font(AppTheme.captionFont)
                            .foregroundStyle(AppTheme.cyan)
                    }
                }
            }
        }
    }

    private var hotNewsInsightCard: some View {
        InsightPanel(title: "热榜趋势", icon: "chart.line.uptrend.xyaxis", tint: AppTheme.pink) {
            if hotNewsStore.topics.isEmpty {
                Text("暂无跨平台主题数据。")
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(hotNewsStore.topics.prefix(3)) { topic in
                        NavigationLink {
                            HotNewsTrendView(topic: topic)
                        } label: {
                            HStack(spacing: 10) {
                                Text("#\(topic.bestRank)")
                                    .font(AppTheme.rankFont)
                                    .foregroundStyle(AppTheme.pink)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(topic.title)
                                        .font(AppTheme.headlineFont)
                                        .foregroundStyle(.white)
                                        .lineLimit(2)
                    Text(topic.platforms.joined(separator: " · "))
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textTertiary)
                    if let duration = topic.duration, duration >= 3600 {
                        Text("持续上榜 \(Int(duration / 3600)) 小时")
                            .font(AppTheme.captionFont)
                            .foregroundStyle(AppTheme.yellow)
                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var anomalyCard: some View {
        InsightPanel(title: "热点异动", icon: "bolt.fill", tint: AppTheme.red) {
            if hotNewsStore.anomalies.isEmpty {
                Text("暂无达到阈值的热点异动。")
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(hotNewsStore.anomalies.prefix(5)) { anomaly in
                        NavigationLink {
                            if let topic = hotNewsStore.topics.first(where: { $0.id == anomaly.topicKey }) {
                                HotNewsTrendView(topic: topic)
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: anomaly.isRising ? "arrow.up.right" : "arrow.down.right")
                                    .foregroundStyle(anomaly.isRising ? AppTheme.green : AppTheme.red)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(anomaly.title).font(AppTheme.headlineFont).foregroundStyle(.white).lineLimit(2)
                                    Text(anomaly.platforms.joined(separator: " · ")).font(AppTheme.captionFont).foregroundStyle(AppTheme.textTertiary)
                                }
                                Spacer()
                                Text(anomaly.isRising ? "+\(anomaly.change)" : "\(anomaly.change)")
                                    .font(AppTheme.headlineFont)
                                    .foregroundStyle(anomaly.isRising ? AppTheme.green : AppTheme.red)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct HotNewsView: View {
    @EnvironmentObject private var hotNewsStore: HotNewsStore
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        hotNewsIntro
                        hotNewsFilters
                        if !hotNewsStore.sourceFailures.isEmpty {
                            Label("部分平台暂时无法获取：\(hotNewsStore.sourceFailures.joined(separator: "、"))", systemImage: "exclamationmark.triangle")
                                .font(AppTheme.captionFont)
                                .foregroundStyle(AppTheme.yellow)
                        }
                        if hotNewsStore.items.isEmpty {
                            VStack(spacing: 12) {
                                FeatureEmptyState(icon: "flame", title: "暂无热榜数据", message: "检查平台开关和 API 地址后重试。")
                                Button("立即刷新") {
                                    Task { await hotNewsStore.refresh(settings: settingsStore.settings, latest: true) }
                                }
                                .buttonStyle(AccentButtonStyle())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 32)
                        } else {
                            ForEach(hotNewsStore.topics) { topic in
                                NavigationLink {
                                    HotNewsTrendView(topic: topic)
                                } label: {
                                    HotNewsTopicCard(topic: topic)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("热榜")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .refreshable { await hotNewsStore.refresh(settings: settingsStore.settings) }
            .task { await hotNewsStore.refresh(settings: settingsStore.settings, showError: false) }
            .alert("热榜刷新", isPresented: Binding(get: { hotNewsStore.errorMessage != nil }, set: { if !$0 { hotNewsStore.errorMessage = nil } })) {
                Button("确定", role: .cancel) { hotNewsStore.errorMessage = nil }
            } message: {
                Text(hotNewsStore.errorMessage ?? "")
            }
        }
    }

    private var hotNewsFilters: some View {
        let platforms = Dictionary(hotNewsStore.items.map { ($0.platformID, $0.platformName) }, uniquingKeysWith: { first, _ in first }).sorted { $0.value < $1.value }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FeedFilterChip(title: "全部平台", isSelected: hotNewsStore.selectedPlatformID == nil) { hotNewsStore.selectedPlatformID = nil }
                ForEach(platforms, id: \.key) { platform in
                    FeedFilterChip(title: platform.value, isSelected: hotNewsStore.selectedPlatformID == platform.key) { hotNewsStore.selectedPlatformID = platform.key }
                }
            }
        }
    }

    private var hotNewsIntro: some View {
        HStack(spacing: 14) {
            Image(systemName: "flame.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(AppTheme.yellow)
                .frame(width: 48, height: 48)
                .background(AppTheme.yellow.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text("实时热点雷达")
                    .font(AppTheme.headlineFont)
                    .foregroundStyle(.white)
                Text("跨平台排名与真实变化趋势")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
        }
        .padding(16)
        .background(AppTheme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct HotNewsTopicCard: View {
    let topic: HotNewsTopic

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(topic.bestRank)")
                .font(AppTheme.rankFont)
                .foregroundStyle(AppTheme.pink)
                .frame(width: 48, alignment: .leading)
            VStack(alignment: .leading, spacing: 5) {
                Text(topic.title)
                    .font(AppTheme.headlineFont)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(topic.platforms.joined(separator: " · "))
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textTertiary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(AppTheme.textTertiary)
        }
        .padding(16)
        .background(AppTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct HotNewsTrendView: View {
    @EnvironmentObject private var hotNewsStore: HotNewsStore
    let topic: HotNewsTopic
    @State private var points: [HotNewsStore.TrendPoint] = []

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(topic.title)
                        .font(AppTheme.titleFont)
                        .foregroundStyle(.white)
                    Text(topic.platforms.joined(separator: " · "))
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("跨平台出现 · 点击查看排名轨迹")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.textTertiary)
                    TrendChart(points: points)
                    ForEach(topic.items) { item in
                        HotNewsTrendRow(item: item)
                    }
                }
                .padding(20)
            }
        }
            .navigationTitle("排名时间线")
        .navigationBarTitleDisplayMode(.inline)
        .task { points = await hotNewsStore.trend(for: topic.id) }
    }
}

private struct HotNewsTrendRow: View {
    let item: HotNewsItem

    var body: some View {
        HStack {
            Text("#\(item.rank)")
                .font(AppTheme.rankFont)
                .foregroundStyle(item.trend == .up ? AppTheme.green : AppTheme.textSecondary)
                .frame(width: 56, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.platformName).font(AppTheme.captionFont).foregroundStyle(AppTheme.yellow)
                Text(item.title).font(AppTheme.headlineFont).foregroundStyle(.white).lineLimit(2)
            }
            Spacer()
        }
        .padding(12)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct TrendChart: View {
    let points: [HotNewsStore.TrendPoint]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppTheme.card)
            if points.count >= 2 {
                Chart(points) { point in
                    LineMark(x: .value("时间", point.date), y: .value("排名", point.rank))
                        .foregroundStyle(AppTheme.pink)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    PointMark(x: .value("时间", point.date), y: .value("排名", point.rank))
                        .foregroundStyle(AppTheme.pink)
                }
                .chartYScale(domain: .automatic(includesZero: false, reversed: true))
                .chartYAxis { AxisMarks(position: .leading) }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
                .padding(14)
                VStack {
                    Spacer()
                    Text("排名越靠前，曲线越接近顶部")
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textTertiary)
                        .padding(.bottom, 10)
                }
            } else {
                Text("数据积累中，至少需要两次采集")
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .frame(height: 220)
    }
}

struct FavoritesView: View {
    @EnvironmentObject private var store: NewsStore

    private var items: [NewsItem] {
        store.items.filter(\.isFavorite)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        archiveHeader
                         if items.isEmpty {
                             FeatureEmptyState(icon: "star", title: "还没有收藏", message: "在发现或订阅页面收藏重要内容，它们会出现在这里。")
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
             .navigationTitle("收藏")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var archiveHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
             Text("SAVED")
                .font(AppTheme.captionFont)
                .tracking(1.6)
                .foregroundStyle(AppTheme.pink)
             Text("保存真正重要的信号")
                .font(AppTheme.titleFont)
                .foregroundStyle(.white)
             Text("集中查看你标记的重要新闻。")
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

}

struct ReportCenterView: View {
    @EnvironmentObject private var store: NewsStore
    @EnvironmentObject private var hotNewsStore: HotNewsStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var reportStore: ReportStore
    @State private var showingReportGenerator = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        reportIntro
                        reportToolbar
                        if reportStore.isLoading {
                            ProgressView("加载报告")
                                .tint(AppTheme.cyan)
                        } else if reportStore.filteredReports.isEmpty {
                            FeatureEmptyState(icon: "doc.text.magnifyingglass", title: "暂无报告", message: "生成一份报告后，它会固定保存当时的新闻快照。")
                                .frame(maxWidth: .infinity)
                                .padding(.top, 32)
                        } else {
                            ForEach(reportStore.filteredReports) { report in
                                NavigationLink {
                                    ReportDetailView(reportID: report.id)
                                } label: {
                                    ReportSummaryCard(report: report)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("报告")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingReportGenerator = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("生成报告")
                }
            }
            .sheet(isPresented: $showingReportGenerator) {
                ReportGeneratorSheet { type in
                    Task {
                        await store.refresh(showError: false, autoReport: false)
                        await hotNewsStore.refresh(settings: settingsStore.settings, showError: false)
                        await reportStore.generate(type: type, settings: settingsStore.settings, items: store.items, hotlistItems: hotNewsStore.items, diagnostics: reportStore.diagnostics(news: store, hotNews: hotNewsStore))
                    }
                }
            }
            .overlay {
                if reportStore.isGenerating {
                    ProgressView("正在生成报告")
                        .padding(20)
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .alert("报告操作", isPresented: Binding(get: { reportStore.errorMessage != nil }, set: { if !$0 { reportStore.errorMessage = nil } })) {
                Button("确定", role: .cancel) { reportStore.errorMessage = nil }
            } message: {
                Text(reportStore.errorMessage ?? "")
            }
            .task { await reportStore.load() }
        }
    }

    private var reportToolbar: some View {
        HStack(spacing: 8) {
            TextField("搜索报告", text: $reportStore.searchText)
                .textFieldStyle(.plain)
                .padding(12)
                .background(AppTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Menu {
                Button("全部类型") { reportStore.selectedType = nil }
                ForEach(ReportType.allCases, id: \.self) { type in
                    Button(type.displayName) { reportStore.selectedType = type }
                }
                Divider()
                Toggle("仅收藏", isOn: $reportStore.favoritesOnly)
            } label: {
                Image(systemName: reportStore.selectedType == nil && !reportStore.favoritesOnly ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.cyan)
            }
        }
    }

    private var reportIntro: some View {
        HStack(spacing: 14) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(AppTheme.pink)
                .frame(width: 48, height: 48)
                .background(AppTheme.pink.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text("本地情报档案")
                    .font(AppTheme.headlineFont)
                    .foregroundStyle(.white)
                Text("保存采集时刻的新闻快照和分析结果")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
        }
        .padding(16)
        .background(AppTheme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct CompactFeedCard: View {
    let item: NewsItem
    @EnvironmentObject private var store: NewsStore

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
                    Text("·")
                    Text(item.isRead ? "已读" : "未读")
                    if item.summary != nil {
                        Text("·")
                        Label("已摘要", systemImage: "sparkles")
                    }
                }
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .padding(16)
        .background(AppTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(item.isRead ? Color.white.opacity(0.05) : AppTheme.cyan.opacity(0.16), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contextMenu {
            Button {
                Task { await store.toggleFavorite(item) }
            } label: {
                Label(item.isFavorite ? "取消收藏" : "收藏", systemImage: item.isFavorite ? "star.slash" : "star")
            }
            if !item.isRead {
                Button {
                    Task { await store.markRead(item) }
                } label: {
                    Label("标记已读", systemImage: "checkmark.circle")
                }
            }
        }
    }
}

struct FeedFilterChip: View {
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

struct InsightPanel<Content: View>: View {
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

struct InsightMetric: View {
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

private struct FeedSummaryMetric: View {
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(AppTheme.rankFont)
                .foregroundStyle(tint)
            Text(label)
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textTertiary)
                .lineLimit(1)
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

struct FeatureEmptyState: View {
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
