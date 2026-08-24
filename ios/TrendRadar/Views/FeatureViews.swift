import SwiftUI
import Charts

struct FeedsView: View {
    @EnvironmentObject private var store: NewsStore
    @EnvironmentObject private var hotNewsStore: HotNewsStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var selectedFeedID: String?
    @State private var showingFeedInfo = false
    @State private var showingSourceManager = false
    @State private var selectedInboxState: InboxState = .unprocessed

    private var enabledFeeds: [ConfigFeed] {
        settingsStore.settings.customFeeds.filter(\.isEnabled)
    }

    private var feedItems: [NewsItem] {
        let filterEngine = FilterEngine(settings: settingsStore.settings)
        let filtered = store.items.filter { filterEngine.includes($0) && $0.inboxState == selectedInboxState }
        guard let selectedFeedID else { return filtered }
        guard let feed = settingsStore.settings.customFeeds.first(where: { $0.id == selectedFeedID }) else { return [] }
        return filtered.filter { $0.source == feed.name }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                IntelligenceScreenBackground()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        IntelligencePageHeader(eyebrow: "SUBSCRIPTION INBOX", title: "订阅与发现", subtitle: "管理信息源，阅读最新内容", icon: "newspaper.fill", assetName: "TrendRadar-SubscriptionHero")
                        feedIntro
                        sourceSummary
                        inboxFilter
                        feedPicker
                        bulkActions
                        if !store.sourceFailures.isEmpty {
                            SourceHealthBanner(title: "部分 RSS 源暂不可用", detail: store.sourceFailures.joined(separator: "、"), tint: AppTheme.yellow)
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
                                .contextMenu {
                                    ForEach(InboxState.allCases, id: \.self) { state in
                                        Button { Task { await store.setInboxState(state, for: item) } } label: {
                                            Label(state.title, systemImage: state.systemImage)
                                        }
                                        .disabled(item.inboxState == state)
                                    }
                                    Button { Task { await store.toggleFavorite(item) } } label: {
                                        Label(item.isFavorite ? "取消收藏" : "收藏", systemImage: item.isFavorite ? "star.slash" : "star")
                                    }
                                }
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSourceManager = true } label: {
                        ToolbarIconLabel(systemName: "slider.horizontal.3", label: "管理信息源")
                    }
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
        .intelligenceCard(tint: AppTheme.brandCyan, cornerRadius: 16)
    }

    private var feedIntro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("管理信息源")
                .font(AppTheme.headlineFont)
                .foregroundStyle(AppTheme.textPrimary)
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

    private var inboxFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(InboxState.allCases, id: \.self) { state in
                    let count = store.items.filter { $0.inboxState == state }.count
                    FeedFilterChip(title: "\(state.title) \(count)", isSelected: selectedInboxState == state) {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedInboxState = state }
                    }
                    .accessibilityLabel("\(state.title)，\(count) 条")
                }
            }
        }
        .accessibilityLabel("收件箱状态筛选")
    }

    private var bulkActions: some View {
        HStack(spacing: 12) {
            Label("当前 \(feedItems.count) 条", systemImage: selectedInboxState.systemImage)
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            if selectedInboxState != .archived, !feedItems.isEmpty {
                Button("全部归档") {
                    let ids = Set(feedItems.map(\.id))
                    Task { await store.setInboxState(.archived, forIDs: ids) }
                }
                .font(AppTheme.captionFont.weight(.semibold))
                .foregroundStyle(AppTheme.cyan)
                .frame(minHeight: 44)
                .accessibilityHint("归档当前筛选结果")
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
            ZStack {
                IntelligenceScreenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        sourceSection(title: "RSS", feeds: settingsStore.settings.customFeeds)
                        sourceSection(title: "热榜来源", platforms: settingsStore.settings.platformSources)
                        PremiumPanel(tint: AppTheme.brandCyan) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("采集设置").font(AppTheme.headlineFont)
                                Toggle("启用 RSS", isOn: $settingsStore.settings.rssEnabled)
                                Toggle("启用热榜", isOn: $settingsStore.settings.platformsEnabled)
                                Toggle("只保留最近文章", isOn: $settingsStore.settings.rssFreshnessEnabled)
                                if settingsStore.settings.rssFreshnessEnabled {
                                    Stepper("文章保留 \(settingsStore.settings.rssMaxAgeDays) 天", value: $settingsStore.settings.rssMaxAgeDays, in: 0...30)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle("订阅源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingFeed = nil
                        showingFeedEditor = true
                    } label: { Text("添加订阅") }
                }
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
            .tint(AppTheme.cyan)
        }
    }

    @ViewBuilder
    private func sourceSection(title: String, feeds: [ConfigFeed]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(AppTheme.sectionTitleFont).foregroundStyle(AppTheme.textSecondary).padding(.horizontal, 8)
            VStack(spacing: 0) {
                ForEach(Array(feeds.enumerated()), id: \.element.id) { index, feed in
                    sourceRow(feed: feed, isLast: index == feeds.count - 1)
                }
            }
            .intelligenceCard(tint: AppTheme.brandCyan, cornerRadius: 20)
        }
    }

    @ViewBuilder
    private func sourceSection(title: String, platforms: [PlatformSource]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(AppTheme.sectionTitleFont).foregroundStyle(AppTheme.textSecondary).padding(.horizontal, 8)
            VStack(spacing: 0) {
                ForEach(Array(platforms.enumerated()), id: \.element.id) { index, source in
                    HStack(spacing: 12) {
                        Toggle("", isOn: Binding(get: { source.isEnabled }, set: { value in
                            if let i = settingsStore.settings.platformSources.firstIndex(where: { $0.id == source.id }) { settingsStore.settings.platformSources[i].isEnabled = value }
                        }))
                        .labelsHidden()
                        Text(source.name).font(AppTheme.cardTitleFont).foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(AppTheme.textTertiary)
                    }
                    .padding(.horizontal, 16).frame(minHeight: 60)
                    if index < platforms.count - 1 { Divider().padding(.leading, 72) }
                }
            }
            .intelligenceCard(tint: AppTheme.brandIndigo, cornerRadius: 20)
        }
    }

    private func sourceRow(feed: ConfigFeed, isLast: Bool) -> some View {
        Button {
            editingFeed = feed
            showingFeedEditor = true
        } label: {
            HStack(spacing: 12) {
                Toggle("", isOn: Binding(get: { feed.isEnabled }, set: { value in
                    if let i = settingsStore.settings.customFeeds.firstIndex(where: { $0.id == feed.id }) { settingsStore.settings.customFeeds[i].isEnabled = value }
                }))
                .labelsHidden()
                VStack(alignment: .leading, spacing: 4) {
                    Text(feed.name).font(AppTheme.cardTitleFont).foregroundStyle(AppTheme.textPrimary)
                    HStack(spacing: 5) {
                        Circle().fill(feed.isEnabled ? AppTheme.green : AppTheme.textTertiary).frame(width: 7, height: 7)
                        Text(feed.isEnabled ? "运行中" : "已停用").font(AppTheme.captionFont).foregroundStyle(AppTheme.textSecondary)
                        if let health = newsStore.feedHealth[feed.id], health.shouldShowWarning { Text("· 连续失败 \(health.consecutiveFailures) 次").font(AppTheme.captionFont).foregroundStyle(AppTheme.yellow) }
                    }
                }
                Spacer()
                Text("编辑").font(AppTheme.headlineFont).foregroundStyle(AppTheme.brandCyan)
                Image(systemName: "chevron.right").foregroundStyle(AppTheme.textTertiary)
            }
            .padding(.horizontal, 16).frame(minHeight: 72)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) { if !isLast { Divider().padding(.leading, 72) } }
    }
}

struct FeedReaderView: View {
    let item: NewsItem
    @EnvironmentObject private var store: NewsStore

    var body: some View {
        ZStack {
            IntelligenceScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageVisualBanner(assetName: "TrendRadar-ReadingHero")
                    Text(item.source.uppercased())
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.cyan)
                    Text(item.title)
                        .font(AppTheme.titleFont)
                        .foregroundStyle(AppTheme.textPrimary)
                    if let author = item.author, !author.isEmpty {
                        Text(author).font(AppTheme.captionFont).foregroundStyle(AppTheme.textSecondary)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Label("离线正文", systemImage: "doc.text")
                            .font(AppTheme.captionFont.weight(.semibold))
                            .foregroundStyle(AppTheme.electricBlue)
                        Text(item.body ?? item.summary ?? "暂无正文缓存")
                            .font(AppTheme.readingFont)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineSpacing(7)
                    }
                    .padding(18)
                    .intelligenceCard(tint: AppTheme.brandIndigo, cornerRadius: 18)
                    if let url = item.url {
                        Link(destination: url) {
                            Label("阅读原文", systemImage: "arrow.up.right")
                        }
                        .buttonStyle(OutlineButtonStyle())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
        }
        .navigationTitle("阅读器")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
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
                IntelligenceScreenBackground()
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
                        latestAIReportCard
                        queryCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle("洞察")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        ReportCenterView()
                    } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("报告中心")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "slider.horizontal.3")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("洞察设置")
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
        IntelligencePageHeader(
            eyebrow: "LOCAL INTELLIGENCE",
            title: "今天值得关注什么",
            subtitle: "基于当前已抓取的新闻与真实排名",
            icon: "sparkles",
            assetName: "TrendRadar-InsightHero"
        )
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
                let aiReady = settingsStore.settings.ai.enabled && settingsStore.settings.aiAnalysis.enabled
                Text(aiReady ? "AI 分析已启用" : "AI 分析未启用")
                    .font(AppTheme.headlineFont)
                    .foregroundStyle(AppTheme.textPrimary)
                Text(aiReady ? "生成后，完整报告会显示在本页下方。" : "请同时启用 AI 分析与结构化报告分析，并配置 API Base URL、Key 和模型。")
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textSecondary)
                if aiReady {
                    Button {
                        generateCurrentAIReport()
                    } label: {
                        Label(isGenerating ? "正在生成并分析" : "生成并展示 \(selectedWindow.title) 报告", systemImage: "doc.text.magnifyingglass")
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

    private func generateCurrentAIReport() {
        guard !isGenerating else { return }
        guard !windowItems.isEmpty || !windowHotlistItems.isEmpty else {
            reportStore.errorMessage = "当前时间范围没有可分析的数据，请先刷新热榜或 RSS。"
            return
        }
        isGenerating = true
        Task {
            defer { isGenerating = false }
            await reportStore.generate(
                type: reportType,
                settings: settingsStore.settings,
                items: windowItems,
                hotlistItems: windowHotlistItems,
                diagnostics: reportStore.diagnostics(news: store, hotNews: hotNewsStore)
            )
            await reportStore.refreshLatestAIAnalysis()
            await loadLatestAnalysis()
        }
    }

    private var latestAIReportCard: some View {
        InsightPanel(title: "AI 分析报告", icon: "doc.text.magnifyingglass", tint: AppTheme.brandIndigo) {
            if let analysis = (reportStore.latestAIAnalysis ?? latestAnalysis), let failure = analysis.failureMessage, !failure.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("本次 AI 分析未生成").font(AppTheme.headlineFont).foregroundStyle(AppTheme.red)
                    Text(failure).font(AppTheme.bodyFont).foregroundStyle(AppTheme.textSecondary)
                    Text("请检查 AI 开关、API Base URL、API Key、模型名称和提示词文件。")
                        .font(AppTheme.captionFont).foregroundStyle(AppTheme.textTertiary)
                }
            } else if let analysis = (reportStore.latestAIAnalysis ?? latestAnalysis), analysis.hasContent {
                VStack(alignment: .leading, spacing: 14) {
                    if let content = analysis.coreTrends ?? analysis.content, !content.isEmpty {
                        insightReportBlock(title: "核心热点态势", content: content)
                    }
                    if let content = analysis.sentimentControversy, !content.isEmpty {
                        insightReportBlock(title: "舆论风向争议", content: content)
                    }
                    if let content = analysis.signals, !content.isEmpty {
                        insightReportBlock(title: "异动与弱信号", content: content)
                    }
                    if let content = analysis.rssInsights, !content.isEmpty {
                        insightReportBlock(title: "RSS 深度洞察", content: content)
                    }
                    if let content = analysis.recommendation, !content.isEmpty {
                        insightReportBlock(title: "研判策略建议", content: content)
                    }
                    if !analysis.standaloneSummaries.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("独立源点速览")
                                .font(AppTheme.headlineFont)
                                .foregroundStyle(AppTheme.brandIndigo)
                            ForEach(analysis.standaloneSummaries.keys.sorted(), id: \.self) { source in
                                if let content = analysis.standaloneSummaries[source], !content.isEmpty {
                                    insightReportBlock(title: source, content: content)
                                }
                            }
                        }
                    }
                    NavigationLink {
                        if let report = reportStore.reports.first {
                            ReportDetailView(reportID: report.id)
                        }
                    } label: {
                        Label("查看完整报告", systemImage: "arrow.up.right")
                    }
                    .buttonStyle(OutlineButtonStyle())
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    if let latest = reportStore.reports.first {
                        Text("最近报告尚未生成 AI 分析")
                            .font(AppTheme.bodyFont)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("报告已保存，但 AI 分析需要单独执行。点击下方按钮即可为这份报告补生成。")
                            .font(AppTheme.captionFont)
                            .foregroundStyle(AppTheme.textSecondary)
                        Button {
                            Task { await reportStore.generateAIAnalysis(for: latest.id, settings: settingsStore.settings) }
                        } label: {
                            Label(reportStore.isGenerating ? "正在生成 AI 分析" : "为最近报告生成 AI 分析", systemImage: "sparkles")
                        }
                        .buttonStyle(AccentButtonStyle())
                        .disabled(reportStore.isGenerating)
                    } else {
                        Text("当前还没有保存的报告。请先生成一份报告。")
                            .font(AppTheme.bodyFont)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func insightReportBlock(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(AppTheme.cardTitleFont)
                .foregroundStyle(AppTheme.brandCyan)
            ReportRichText(content: content)
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
                    .foregroundStyle(AppTheme.textPrimary)
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
                                        .foregroundStyle(AppTheme.textPrimary)
                                        .lineLimit(3)
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
                                    Text(anomaly.title).font(AppTheme.cardTitleFont).foregroundStyle(AppTheme.textPrimary).lineLimit(3)
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
                IntelligenceScreenBackground()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        IntelligencePageHeader(eyebrow: "LIVE RADAR", title: "热榜雷达", subtitle: "跨平台排名与真实变化趋势", icon: "dot.radiowaves.left.and.right", assetName: "TrendRadar-RadarHero")
                        hotNewsOverview
                        radarSummary
                        radarStateFilters
                        hotNewsFilters
                        if !hotNewsStore.sourceFailures.isEmpty {
                            SourceHealthBanner(title: "部分热榜平台暂不可用", detail: hotNewsStore.sourceFailures.joined(separator: "、"), tint: AppTheme.yellow)
                        }
                        if hotNewsStore.items.isEmpty {
                            VStack(spacing: 10) {
                                HStack(spacing: 12) {
                                    Image(systemName: "flame.slash")
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundStyle(AppTheme.yellow)
                                        .frame(width: 44, height: 44)
                                        .background(AppTheme.yellow.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("暂无热榜缓存")
                                            .font(AppTheme.headlineFont)
                                            .foregroundStyle(AppTheme.textPrimary)
                                        Text("进入热榜页刷新后，这里会显示实时信号")
                                            .font(AppTheme.captionFont)
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }
                                    Spacer(minLength: 0)
                                }
                                Button {
                                    Task { await hotNewsStore.refresh(settings: settingsStore.settings, latest: true) }
                                } label: {
                                    Label("立即刷新", systemImage: "arrow.clockwise")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(AccentButtonStyle())
                            }
                            .padding(16)
                            .intelligenceCard(tint: AppTheme.yellow, cornerRadius: 16)
                        } else {
                            if hotNewsStore.radarTopics.isEmpty {
                                FeatureEmptyState(icon: "line.3.horizontal.decrease.circle", title: "没有符合条件的趋势", message: "切换筛选条件，或刷新以获取新的真实排名快照。")
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 24)
                            }
                            ForEach(hotNewsStore.radarTopics) { topic in
                                NavigationLink(value: topic) {
                                    HotNewsTopicCard(topic: topic)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 150)
                }
            }
            .navigationTitle("热榜")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .navigationDestination(for: HotNewsTopic.self) { topic in
                HotNewsTrendView(topic: topic)
            }
            .refreshable { await hotNewsStore.refresh(settings: settingsStore.settings) }
            .task { await hotNewsStore.refresh(settings: settingsStore.settings, showError: false) }
            .alert("热榜刷新", isPresented: Binding(get: { hotNewsStore.errorMessage != nil }, set: { if !$0 { hotNewsStore.errorMessage = nil } })) {
                Button("确定", role: .cancel) { hotNewsStore.errorMessage = nil }
            } message: {
                Text(hotNewsStore.errorMessage ?? "")
            }
        }
    }

    private var radarStateFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RadarFilter.allCases) { filter in
                    Button {
                        withAnimation(AppAnimation.standard) { hotNewsStore.selectedRadarFilter = filter }
                    } label: {
                        IntelligenceFilterChip(filter.title, icon: filter.systemImage, isSelected: hotNewsStore.selectedRadarFilter == filter)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(hotNewsStore.selectedRadarFilter == filter ? .isSelected : [])
                }
            }
        }
    }

    private var hotNewsOverview: some View {
        HStack(spacing: 10) {
            PremiumMetricCard(value: "\(hotNewsStore.items.count)", label: "热点", icon: "flame.fill", tint: AppTheme.yellow)
            PremiumMetricCard(value: "\(Set(hotNewsStore.items.map(\.platformID)).count)", label: "平台", icon: "square.grid.2x2", tint: AppTheme.brandCyan)
            PremiumMetricCard(value: "\(hotNewsStore.sourceFailures.count)", label: "异常", icon: "exclamationmark.triangle", tint: hotNewsStore.sourceFailures.isEmpty ? AppTheme.green : AppTheme.yellow)
        }
    }

    private var radarSummary: some View {
        PremiumPanel(tint: AppTheme.brandCyan) {
            HStack(spacing: 18) {
                RadarDecoration(count: hotNewsStore.items.count)
                    .frame(width: 150, height: 170)
                VStack(alignment: .leading, spacing: 10) {
                    Text("实时信号扫描")
                        .font(AppTheme.headlineFont)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(hotNewsStore.lastUpdated.map { "更新于 \($0, format: .dateTime.hour().minute())" } ?? "等待首次刷新")
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textSecondary)
                    PremiumStatusLine(title: "数据平台", detail: "\(Set(hotNewsStore.items.map(\.platformID)).count) 个", isGood: !hotNewsStore.items.isEmpty)
                    PremiumStatusLine(title: "排名轨迹", detail: hotNewsStore.items.contains { $0.previousRank != nil } ? "可用" : "积累中", isGood: hotNewsStore.items.contains { $0.previousRank != nil })
                }
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
                    .foregroundStyle(AppTheme.textPrimary)
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let topic: HotNewsTopic

    private var trendText: String {
        guard let item = topic.items.min(by: { $0.rank < $1.rank }), let previous = item.previousRank else { return "新" }
        let delta = previous - item.rank
        return delta == 0 ? "—" : delta > 0 ? "↑ \(delta)" : "↓ \(abs(delta))"
    }

    private var trendTint: Color {
        topic.strongestTrend == .up ? AppTheme.brandCyan : topic.strongestTrend == .new ? AppTheme.yellow : AppTheme.textTertiary
    }

    var body: some View {
        HStack(spacing: 14) {
            Text("\(topic.bestRank)")
                .font(AppTheme.rankFont)
                .foregroundStyle(topic.bestRank <= 3 ? AppTheme.pink : AppTheme.textTertiary)
                .frame(width: 42, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
                Text(topic.title)
                    .font(AppTheme.cardTitleFont)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                HStack(spacing: 6) {
                    Text(topic.platforms.joined(separator: " · "))
                    Text("·")
                    Text("热度实时")
                }
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textTertiary)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 5) {
                Text(trendText)
                    .font(AppTheme.headlineFont.monospacedDigit())
                    .foregroundStyle(trendTint)
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .intelligenceCard(tint: trendTint, cornerRadius: 16)
    }
}

struct HotNewsTrendView: View {
    @EnvironmentObject private var hotNewsStore: HotNewsStore
    let topic: HotNewsTopic
    @State private var snapshots: [RankSnapshot] = []
    @State private var isFollowing = false

    var body: some View {
        ZStack {
            IntelligenceScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageVisualBanner(assetName: "TrendRadar-RadarHero", height: 120)
                    Text(topic.title)
                        .font(AppTheme.titleFont)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(topic.platforms.joined(separator: " · "))
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("跨平台出现 · 点击查看排名轨迹")
                        .font(AppTheme.metadataFont)
                        .foregroundStyle(AppTheme.textTertiary)
                    trendMetrics
                    TrendChart(snapshots: snapshots)
                        .padding(16)
                        .intelligenceCard(tint: AppTheme.electricBlue, cornerRadius: 18)
                    sourceDistribution
                        .padding(16)
                        .intelligenceCard(tint: AppTheme.brandIndigo, cornerRadius: 18)
                    ForEach(topic.items) { item in
                        HotNewsTrendRow(item: item)
                    }
                }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 120)
                }
            }
        .navigationTitle("排名时间线")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isFollowing.toggle()
                    Task { await hotNewsStore.toggleFavorite(for: topic) }
                } label: {
                    ToolbarIconLabel(systemName: isFollowing ? "star.fill" : "star", label: isFollowing ? "取消关注主题" : "关注主题", tint: isFollowing ? AppTheme.yellow : AppTheme.textPrimary)
                }
            }
        }
        .task {
            isFollowing = topic.items.contains(where: \.isFavorite)
            snapshots = await hotNewsStore.rankSnapshots(for: topic.id)
        }
    }

    private var trendMetrics: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                StatusBadge(title: "最佳 #\(topic.bestRank)", systemImage: "number", tint: AppTheme.brandCyan)
                StatusBadge(title: "\(topic.platformCount) 个平台", systemImage: "square.stack.3d.up", tint: AppTheme.green)
                StatusBadge(title: "\(snapshots.count) 次快照", systemImage: "clock.arrow.circlepath", tint: AppTheme.yellow)
            }
        }
    }

    private var sourceDistribution: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("来源分布")
                .font(AppTheme.headlineFont)
                .foregroundStyle(AppTheme.textPrimary)
            ForEach(Dictionary(grouping: topic.items, by: \.platformName).keys.sorted(), id: \.self) { name in
                HStack {
                    Text(name)
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Text("\(topic.items.filter { $0.platformName == name }.count) 条")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(AppTheme.textTertiary)
                }
                Divider()
            }
        }
        .padding(16)
        .intelligenceCard(tint: AppTheme.brandIndigo, cornerRadius: 16)
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
                Text(item.title).font(AppTheme.cardTitleFont).foregroundStyle(AppTheme.textPrimary).lineLimit(3)
            }
            Spacer()
        }
        .padding(12)
        .intelligenceCard(tint: item.trend == .up ? AppTheme.green : AppTheme.brandIndigo, cornerRadius: 14)
    }
}

private struct TrendChart: View {
    let snapshots: [RankSnapshot]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppTheme.card)
            if snapshots.count >= 2 {
                Chart(snapshots) { snapshot in
                    LineMark(x: .value("时间", snapshot.capturedAt), y: .value("排名", snapshot.rank))
                        .foregroundStyle(by: .value("平台", snapshot.sourceName))
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    PointMark(x: .value("时间", snapshot.capturedAt), y: .value("排名", snapshot.rank))
                        .foregroundStyle(by: .value("平台", snapshot.sourceName))
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

private extension RadarFilter {
    var title: String {
        switch self {
        case .all: return "全部"
        case .rising: return "上升"
        case .new: return "新进"
        case .sustained: return "持续"
        case .following: return "关注"
        }
    }

    var systemImage: String {
        switch self {
        case .all: return "line.3.horizontal.decrease"
        case .rising: return "arrow.up.right"
        case .new: return "sparkles"
        case .sustained: return "clock"
        case .following: return "star"
        }
    }
}

struct FavoritesView: View {
    @EnvironmentObject private var store: NewsStore
    @EnvironmentObject private var hotNewsStore: HotNewsStore
    @EnvironmentObject private var reportStore: ReportStore
    @EnvironmentObject private var archiveStore: ArchiveStore
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                IntelligenceScreenBackground()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        archiveHeader
                        archiveFilter
                         if archiveStore.filteredItems.isEmpty {
                             FeatureEmptyState(icon: "archivebox", title: "资料库还是空的", message: "收藏趋势或报告，或在订阅中归档文章，它们会安全保存在这里。")
                                .frame(maxWidth: .infinity)
                                .padding(.top, 32)
                        } else {
                            ForEach(archiveStore.filteredItems) { resource in
                                NavigationLink(value: resource) {
                                    ArchiveResourceRow(resource: resource)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    ShareLink(item: resource.shareText) { Label("分享", systemImage: "square.and.arrow.up") }
                                    Button(role: .destructive) { Task { await archiveStore.delete(resource) } } label: {
                                        Label("移出资料库", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 120)
                }
            }
             .navigationTitle("资料库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: {
                        ToolbarIconLabel(systemName: "gearshape", label: "设置")
                    }
                }
            }
            .searchable(text: $archiveStore.searchText, prompt: "搜索标题、来源和摘要")
            .navigationDestination(for: ArchiveResource.self) { resource in
                archiveDestination(resource)
            }
            .task {
                await archiveStore.synchronize(news: store.items, topics: hotNewsStore.topics, reports: reportStore.reports)
            }
            .alert("资料库", isPresented: Binding(get: { archiveStore.errorMessage != nil }, set: { if !$0 { archiveStore.errorMessage = nil } })) {
                Button("确定", role: .cancel) { archiveStore.errorMessage = nil }
            } message: { Text(archiveStore.errorMessage ?? "") }
            .sheet(isPresented: $showingSettings) { SettingsView() }
        }
    }

    private var archiveHeader: some View {
        IntelligencePageHeader(
            eyebrow: "LOCAL LIBRARY",
            title: "保存真正重要的信号",
            subtitle: "新闻、趋势和报告统一归档，随时检索与分享",
            icon: "archivebox.fill",
            assetName: "TrendRadar-LibraryHero"
        )
    }

    private var archiveFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FeedFilterChip(title: "全部 \(archiveStore.items.count)", isSelected: archiveStore.selectedKind == nil) { archiveStore.selectedKind = nil }
                ForEach(ArchiveResourceKind.allCases, id: \.self) { kind in
                    let count = archiveStore.items.filter { $0.kind == kind }.count
                    FeedFilterChip(title: "\(kind.title) \(count)", isSelected: archiveStore.selectedKind == kind) { archiveStore.selectedKind = kind }
                }
            }
        }
        .accessibilityLabel("资料类型筛选")
    }

    @ViewBuilder
    private func archiveDestination(_ resource: ArchiveResource) -> some View {
        switch resource.kind {
        case .rss:
            if let item = store.items.first(where: { $0.id == resource.resourceID }) { NewsDetailView(item: item) }
            else { ArchiveSnapshotView(resource: resource) }
        case .hotlist:
            if let topic = hotNewsStore.topics.first(where: { $0.id == resource.resourceID }) { HotNewsTrendView(topic: topic) }
            else { ArchiveSnapshotView(resource: resource) }
        case .report:
            if let id = UUID(uuidString: resource.resourceID), reportStore.reports.contains(where: { $0.id == id }) { ReportDetailView(reportID: id) }
            else { ArchiveSnapshotView(resource: resource) }
        }
    }
}

private struct ArchiveResourceRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let resource: ArchiveResource

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: resource.kind.systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.cyan)
                .frame(width: 42, height: 42)
                .background(AppTheme.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(resource.title).font(AppTheme.cardTitleFont).foregroundStyle(AppTheme.textPrimary).lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                Text("\(resource.kind.title) · \(resource.source)").font(AppTheme.captionFont).foregroundStyle(AppTheme.textSecondary).lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                Text(resource.capturedAt, format: .relative(presentation: .named)).font(AppTheme.captionFont).foregroundStyle(AppTheme.textTertiary)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").foregroundStyle(AppTheme.textTertiary).accessibilityHidden(true)
        }
        .padding(14)
        .intelligenceCard(tint: AppTheme.cyan, cornerRadius: 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(resource.kind.title)，\(resource.title)，来源 \(resource.source)")
    }
}

private struct ArchiveSnapshotView: View {
    let resource: ArchiveResource

    var body: some View {
        IntelligencePage {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    StatusBadge(title: resource.kind.title, systemImage: resource.kind.systemImage, tint: AppTheme.cyan)
                    Text(resource.title).font(AppTheme.titleFont).foregroundStyle(AppTheme.textPrimary)
                    Text(resource.source).font(AppTheme.captionFont).foregroundStyle(AppTheme.textSecondary)
                    if let summary = resource.summary { Text(summary).font(AppTheme.bodyFont).foregroundStyle(AppTheme.textSecondary) }
                    if let url = resource.url { Link(destination: url) { Label("打开原文", systemImage: "arrow.up.right") }.buttonStyle(OutlineButtonStyle()) }
                    ShareLink(item: resource.shareText) { Label("分享资料", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }
                        .buttonStyle(AccentButtonStyle()).frame(minHeight: 44)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
        }
        .navigationTitle("归档快照")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
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
                IntelligenceScreenBackground()
                LinearGradient(colors: [AppTheme.brandIndigo.opacity(0.12), .clear], startPoint: .topLeading, endPoint: .center)
                    .ignoresSafeArea()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        reportIntro
                        reportStatusStrip
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
                                .contextMenu {
                                    Button {
                                        Task { await reportStore.toggleFavorite(id: report.id) }
                                    } label: {
                                        Label(report.isFavorite ? "取消收藏" : "收藏", systemImage: report.isFavorite ? "star.slash" : "star")
                                    }
                                    Button(role: .destructive) {
                                        Task { await reportStore.delete(id: report.id) }
                                    } label: {
                                        Label("删除报告", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 150)
                }
            }
            .navigationTitle("报告")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingReportGenerator = true } label: {
                        ToolbarIconLabel(systemName: "plus", label: "生成报告")
                    }
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
                        .intelligenceCard(tint: AppTheme.brandCyan, cornerRadius: 14)
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

    private var reportStatusStrip: some View {
        HStack(spacing: 8) {
            PremiumMetricCard(value: "\(reportStore.reports.count)", label: "全部报告", icon: "doc.text", tint: AppTheme.brandCyan)
            PremiumMetricCard(value: "\(reportStore.reports.filter(\.isFavorite).count)", label: "已收藏", icon: "star.fill", tint: AppTheme.yellow)
            PremiumMetricCard(value: "\(reportStore.reports.filter { $0.type == .daily }.count)", label: "日报", icon: "calendar", tint: AppTheme.brandMagenta)
        }
    }

    private var reportToolbar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                    .foregroundStyle(AppTheme.brandCyan)
                Text("报告检索")
                    .font(AppTheme.headlineFont)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text(reportStore.favoritesOnly ? "仅收藏" : reportStore.selectedType?.displayName ?? "全部类型")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(AppTheme.brandCyan)
                    TextField("搜索报告标题", text: $reportStore.searchText)
                        .textFieldStyle(.plain)
                    if !reportStore.searchText.isEmpty {
                        Button { reportStore.searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .intelligenceCard(tint: AppTheme.brandCyan, cornerRadius: 12)
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
                        .frame(width: 42, height: 42)
                        .intelligenceCard(tint: AppTheme.brandCyan, cornerRadius: 12)
                }
            }
        }
    }

    private var reportIntro: some View {
        IntelligencePageHeader(
            eyebrow: "REPORT ARCHIVE",
            title: "本地情报档案",
            subtitle: "保存采集时刻的新闻快照和分析结果",
            icon: "doc.text.magnifyingglass",
            assetName: "TrendRadar-ReportsHero"
        )
    }
}

struct CompactFeedCard: View {
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
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
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
        .intelligenceCard(tint: item.isRead ? AppTheme.textTertiary : AppTheme.cyan, cornerRadius: 16)
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
            IntelligenceFilterChip(title, isSelected: isSelected)
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
        .intelligenceCard(tint: tint, cornerRadius: 18)
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

struct SourceHealthBanner: View {
    let title: String
    let detail: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(AppTheme.headlineFont).foregroundStyle(AppTheme.textPrimary)
                Text(detail).font(AppTheme.captionFont).foregroundStyle(AppTheme.textSecondary).lineLimit(3)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(tint.opacity(0.09))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(tint.opacity(0.28), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct FeatureEmptyState: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            if !dynamicTypeSize.isAccessibilitySize {
                Image("TrendRadar-EmptyState")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 220, maxHeight: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        LinearGradient(colors: [.clear, AppTheme.background.opacity(0.22)], startPoint: .top, endPoint: .bottom)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .accessibilityHidden(true)
            }
            Image(systemName: icon)
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(AppTheme.brandCyan)
            Text(title)
                .font(AppTheme.sectionTitleFont)
                .foregroundStyle(AppTheme.textPrimary)
            Text(message)
                .font(AppTheme.bodyFont)
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
                Image("TrendRadar-Webhook")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 150)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(AppTheme.cyan)
                Text("已启用 \(feedCount) 个订阅源")
                    .font(AppTheme.sectionTitleFont)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("RSS 与 Atom 内容会在刷新时并发抓取，并保存到本地情报库。")
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Spacer()
            }
            .padding(.top, 48)
            .frame(maxWidth: .infinity)
            .background(IntelligenceScreenBackground())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
        }
        .tint(AppTheme.cyan)
    }
}
