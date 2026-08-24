import SwiftUI
import Charts

struct FeedsView: View {
    @EnvironmentObject private var store: NewsStore
    @EnvironmentObject private var hotNewsStore: HotNewsStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var selectedFeedID: String?
    @State private var showingFeedInfo = false
    @State private var showingSourceManager = false
    @State private var showingDiscover = false
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
                        sourceSummary
                        inboxFilter
                        feedPicker
                        bulkActions
                        if !store.sourceFailures.isEmpty {
                            SourceHealthBanner(title: "éƒ¨åˆ† RSS æºæš‚ä¸å¯ç”¨", detail: store.sourceFailures.joined(separator: "ã€"), tint: AppTheme.yellow)
                        }
                        if enabledFeeds.isEmpty {
                            FeatureEmptyState(icon: "antenna.radiowaves.left.and.right.slash", title: "è¿˜æ²¡æœ‰å¯ç”¨è®¢é˜…æº", message: "åœ¨æ¥æºç®¡ç†ä¸­å¯ç”¨ RSS æºï¼Œå†å›æ¥åˆ·æ–°ä½ çš„ä¿¡æ¯æµã€‚", actionTitle: "ç®¡ç†è®¢é˜…æº") {
                                showingSourceManager = true
                            }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 32)
                        } else if feedItems.isEmpty {
                            FeatureEmptyState(icon: "newspaper", title: "æš‚æ— è®¢é˜…å†…å®¹", message: "åˆ·æ–°å·²å¯ç”¨çš„ RSS æºï¼Œè·å–æœ€æ–°è®¢é˜…æ–‡ç« ã€‚", actionTitle: "ç«‹å³åˆ·æ–°") {
                                Task { await store.refresh() }
                            }
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
                                        Label(item.isFavorite ? "å–æ¶ˆæ”¶è—" : "æ”¶è—", systemImage: item.isFavorite ? "star.slash" : "star")
                                    }
                                }
                                .overlay(alignment: .topTrailing) {
                                    if relatedTopic(for: item) != nil {
                                        Text("å…³è”çƒ­æ¦œ")
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
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                }
                .refreshable { await store.refresh() }
            }
            .navigationTitle("è®¢é˜…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingDiscover = true } label: {
                        ToolbarIconLabel(systemName: "magnifyingglass.circle", label: "å‘ç°ä¸æ£€ç´¢")
                    }
                    .buttonStyle(.plain)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSourceManager = true } label: {
                        ToolbarIconLabel(systemName: "slider.horizontal.3", label: "ç®¡ç†ä¿¡æ¯æº")
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(isPresented: $showingFeedInfo) {
                FeedInfoSheet(feedCount: enabledFeeds.count)
            }
            .sheet(isPresented: $showingSourceManager) {
                SubscriptionSourceManager()
            }
            .sheet(isPresented: $showingDiscover) {
                DiscoverHubView()
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
            FeedSummaryMetric(value: "\(enabledFeeds.count)", label: "RSS æº", tint: AppTheme.cyan)
            FeedSummaryMetric(value: "\(settingsStore.settings.platformSources.filter(\.isEnabled).count)", label: "çƒ­æ¦œå¹³å°", tint: AppTheme.pink)
            FeedSummaryMetric(value: "\(feedItems.filter { !$0.isRead }.count)", label: "å¾…é˜…è¯»", tint: AppTheme.yellow)
        }
        .padding(16)
        .intelligenceCard(tint: AppTheme.brandCyan, cornerRadius: 16)
    }

    private var feedIntro: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("ç®¡ç†ä¿¡æ¯æº")
                    .font(AppTheme.headlineFont)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("é€‰æ‹©æ¥æºï¼Œé˜…è¯»å¯¹åº”çš„è®¢é˜…å†…å®¹ã€‚")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 0)
            Button { showingFeedInfo = true } label: {
                Image(systemName: "info.circle")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("è®¢é˜…è¿è¡Œè¯´æ˜")
        }
        .padding(16)
        .background(AppTheme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var feedPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FeedFilterChip(title: "å…¨éƒ¨", isSelected: selectedFeedID == nil) { selectedFeedID = nil }
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
                    .accessibilityLabel("\(state.title)ï¼Œ\(count) æ¡")
                }
            }
        }
        .accessibilityLabel("æ”¶ä»¶ç®±çŠ¶æ€ç­›é€‰")
    }

    private var bulkActions: some View {
        HStack(spacing: 12) {
            Label("å½“å‰ \(feedItems.count) æ¡", systemImage: selectedInboxState.systemImage)
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            if selectedInboxState != .archived, !feedItems.isEmpty {
                Button("å…¨éƒ¨å½’æ¡£") {
                    let ids = Set(feedItems.map(\.id))
                    Task { await store.setInboxState(.archived, forIDs: ids) }
                }
                .font(AppTheme.captionFont.weight(.semibold))
                .foregroundStyle(AppTheme.cyan)
                .frame(minHeight: 44)
                .accessibilityHint("å½’æ¡£å½“å‰ç­›é€‰ç»“æœ")
            }
        }
    }

    private var feedSummary: some View {
        HStack(spacing: 12) {
            FeedSummaryMetric(value: "\(enabledFeeds.count)", label: "å¯ç”¨æº", tint: AppTheme.cyan)
            FeedSummaryMetric(value: "\(feedItems.count)", label: selectedFeedID == nil ? "å…¨éƒ¨æ–‡ç« " : "å½“å‰æºæ–‡ç« ", tint: AppTheme.yellow)
            FeedSummaryMetric(value: "\(feedItems.filter { !$0.isRead }.count)", label: "å¾…é˜…è¯»", tint: AppTheme.pink)
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
                        sourceSection(title: "çƒ­æ¦œæ¥æº", platforms: settingsStore.settings.platformSources)
                        PremiumPanel(tint: AppTheme.brandCyan) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("é‡‡é›†è®¾ç½®").font(AppTheme.headlineFont)
                                Toggle("å¯ç”¨ RSS", isOn: $settingsStore.settings.rssEnabled)
                                Toggle("å¯ç”¨çƒ­æ¦œ", isOn: $settingsStore.settings.platformsEnabled)
                                Toggle("åªä¿ç•™æœ€è¿‘æ–‡ç« ", isOn: $settingsStore.settings.rssFreshnessEnabled)
                                if settingsStore.settings.rssFreshnessEnabled {
                                    Stepper("æ–‡ç« ä¿ç•™ \(settingsStore.settings.rssMaxAgeDays) å¤©", value: $settingsStore.settings.rssMaxAgeDays, in: 0...30)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("è®¢é˜…æº")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingFeed = nil
                        showingFeedEditor = true
                    } label: { Text("æ·»åŠ è®¢é˜…") }
                }
            }
            .sheet(isPresented: $showingFeedEditor) {
                FeedEditorView(feed: editingFeed, onSave: { feed in
                    if let index = settingsStore.settings.customFeeds.firstIndex(where: { $0.id == feed.id }) {
                        settingsStore.settings.customFeeds[index] = feed
                    } else {
                        settingsStore.settings.customFeeds.append(feed)
                    }
                    editingFeed = nil
                }, onDelete: editingFeed.map { target in
                    { settingsStore.settings.customFeeds.removeAll { $0.id == target.id }; editingFeed = nil }
                })
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
                        Text(feed.isEnabled ? "è¿è¡Œä¸­" : "å·²åœç”¨").font(AppTheme.captionFont).foregroundStyle(AppTheme.textSecondary)
                        Text("Â· \(newsStore.items.filter { $0.source == feed.name }.count) æ¡").font(AppTheme.captionFont).foregroundStyle(AppTheme.textTertiary)
                        if let health = newsStore.feedHealth[feed.id], health.shouldShowWarning { Text("Â· è¿ç»­å¤±è´¥ \(health.consecutiveFailures) æ¬¡").font(AppTheme.captionFont).foregroundStyle(AppTheme.yellow) }
                    }
                    if let lastSuccess = newsStore.feedHealth[feed.id]?.lastSuccessAt {
                        Text("æœ€è¿‘æˆåŠŸï¼š\(lastSuccess.formatted(date: .omitted, time: .shortened))").font(AppTheme.metadataFont).foregroundStyle(AppTheme.textTertiary)
                    }
                }
                Spacer()
                Text("ç¼–è¾‘").font(AppTheme.headlineFont).foregroundStyle(AppTheme.brandCyan)
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
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var translatedTitle: String?
    @State private var isTranslating = false
    @AppStorage("reader.fontScale") private var readerFontScale = 1.0
    @AppStorage("reader.lineSpacing") private var readerLineSpacing = 7.0
    @AppStorage("reader.sepia") private var readerSepia = false
    @State private var readingProgress = 0.0

    private var paragraphs: [String] {
        (item.body ?? item.summary ?? "æš‚æ— æ­£æ–‡ç¼“å­˜")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        ZStack {
            IntelligenceScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack { Text("é˜…è¯»è¿›åº¦"); Spacer(); Text("\(Int(readingProgress * 100))%") }
                            .font(AppTheme.metadataFont).foregroundStyle(AppTheme.textTertiary)
                        ProgressView(value: readingProgress).tint(AppTheme.brandCyan)
                    }
                    Text(item.source.uppercased())
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.cyan)
                    Text(translatedTitle ?? item.translatedTitle ?? item.title)
                        .font(AppTheme.titleFont)
                        .foregroundStyle(AppTheme.textPrimary)
                    if translatedTitle != nil || item.translatedTitle != nil {
                        Text(item.title)
                            .font(AppTheme.captionFont)
                            .foregroundStyle(AppTheme.textSecondary)
                            .accessibilityLabel("åŸæ–‡æ ‡é¢˜ï¼š\(item.title)")
                    }
                    if let author = item.author, !author.isEmpty {
                        Text(author).font(AppTheme.captionFont).foregroundStyle(AppTheme.textSecondary)
                    }
                    LazyVStack(alignment: .leading, spacing: 12) {
                        Label("ç¦»çº¿æ­£æ–‡", systemImage: "doc.text")
                            .font(AppTheme.captionFont.weight(.semibold))
                            .foregroundStyle(AppTheme.electricBlue)
                        ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                            Text(paragraph)
                                .font(.system(size: 17 * readerFontScale, design: readerSepia ? .serif : .default))
                                .foregroundStyle(readerSepia ? AppTheme.readerText : AppTheme.textSecondary)
                                .lineSpacing(readerLineSpacing)
                                .onAppear { readingProgress = max(readingProgress, Double(index + 1) / Double(max(1, paragraphs.count))) }
                        }
                    }
                    .padding(18)
                    .background(readerSepia ? AppTheme.readerSurface : Color.clear)
                    .intelligenceCard(tint: AppTheme.brandIndigo, cornerRadius: 18)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) { readerActions }
                        VStack(alignment: .leading, spacing: 10) { readerActions }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("é˜…è¯»å™¨")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Picker("å­—å·", selection: $readerFontScale) {
                        Text("å°").tag(0.9); Text("æ ‡å‡†").tag(1.0); Text("å¤§").tag(1.15); Text("ç‰¹å¤§").tag(1.3)
                    }
                    Picker("è¡Œè·", selection: $readerLineSpacing) {
                        Text("ç´§å‡‘").tag(4.0); Text("æ ‡å‡†").tag(7.0); Text("å®½æ¾").tag(11.0)
                    }
                    Toggle("æŠ¤çœ¼é˜…è¯»è‰²", isOn: $readerSepia)
                } label: { ToolbarIconLabel(systemName: "textformat.size", label: "é˜…è¯»è®¾ç½®") }
                ShareLink(item: item.url?.absoluteString ?? item.title) {
                    ToolbarIconLabel(systemName: "square.and.arrow.up", label: "åˆ†äº«æ–‡ç« ")
                }
            }
        }
        .task {
            translatedTitle = store.items.first(where: { $0.id == item.id })?.translatedTitle ?? item.translatedTitle
            await store.markRead(item)
        }
    }

    @ViewBuilder
    private var readerActions: some View {
        if settingsStore.settings.aiTranslation.enabled && settingsStore.settings.aiTranslation.translateRSS {
            Button {
                isTranslating = true
                Task {
                    translatedTitle = await store.translateTitle(item)
                    isTranslating = false
                }
            } label: {
                Label(isTranslating ? "ç¿»è¯‘ä¸­" : (translatedTitle == nil && item.translatedTitle == nil ? "ç¿»è¯‘æ ‡é¢˜" : "é‡æ–°ç¿»è¯‘"), systemImage: "character.book.closed")
            }
            .buttonStyle(AccentButtonStyle())
            .disabled(isTranslating)
        }
        if let url = item.url {
            Link(destination: url) { Label("é˜…è¯»åŸæ–‡", systemImage: "arrow.up.right") }
                .buttonStyle(OutlineButtonStyle())
        }
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
    @State private var actionFeedback: ActionFeedback?

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
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("æ´å¯Ÿ")
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
                    .accessibilityLabel("æŠ¥å‘Šä¸­å¿ƒ")
                    .buttonStyle(.plain)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "slider.horizontal.3")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("æ´å¯Ÿè®¾ç½®")
                    .buttonStyle(.plain)
                }
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .task {
                await reportStore.load()
                await loadLatestAnalysis()
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
    }

    private func loadLatestAnalysis() async {
        guard let latest = reportStore.reports.max(by: { $0.generatedAt < $1.generatedAt }) else {
            latestAnalysis = nil
            return
        }
        latestAnalysis = await reportStore.detail(id: latest.id)?.aiAnalysis
    }

    private var insightHeader: some View {
        IntelligencePageHeader(
            eyebrow: "LOCAL INTELLIGENCE",
            title: "ä»Šå¤©å€¼å¾—å…³æ³¨ä»€ä¹ˆ",
            subtitle: "åŸºäºå½“å‰å·²æŠ“å–çš„æ–°é—»ä¸çœŸå®æ’å",
            icon: "sparkles"
        )
    }

    private var windowItems: [NewsItem] {
        store.items.filter { selectedWindow.includes($0.publishedAt) }
    }

    private var windowHotlistItems: [HotNewsItem] {
        hotNewsStore.items.filter { selectedWindow.includes($0.publishedAt) }
    }

    private var insightWindowPicker: some View {
        Picker("åˆ†æèŒƒå›´", selection: $selectedWindow) {
            ForEach(InsightTimeWindow.allCases, id: \.self) { window in
                Text(window.title).tag(window)
            }
        }
        .pickerStyle(.segmented)
    }

    private var signalCard: some View {
        InsightPanel(title: "æƒ…æŠ¥è„‰æ", icon: "waveform.path.ecg", tint: AppTheme.cyan) {
            HStack(spacing: 12) {
                InsightMetric(value: "\(windowItems.count + windowHotlistItems.count)", label: "åˆ†ææ ·æœ¬", tint: AppTheme.cyan)
                InsightMetric(value: "\(keywordMatches.count)", label: "å…³æ³¨å‘½ä¸­", tint: AppTheme.yellow)
                InsightMetric(value: "\(windowItems.filter { !$0.isRead }.count)", label: "å¾…é˜…è¯»", tint: AppTheme.pink)
            }
        }
    }

    private var sentimentCard: some View {
        let sentiment = localSentiment
        return InsightPanel(title: "æƒ…ç»ªé¢æ¿", icon: "gauge.with.dots.needle.67percent", tint: AppTheme.pink) {
            if sentiment.isComputed {
                HStack(spacing: 12) {
                    InsightMetric(value: "\(Int(sentiment.positive * 100))%", label: "æ­£é¢", tint: AppTheme.green)
                    InsightMetric(value: "\(Int(sentiment.neutral * 100))%", label: "ä¸­ç«‹", tint: AppTheme.textSecondary)
                    InsightMetric(value: "\(Int(sentiment.negative * 100))%", label: "è´Ÿé¢", tint: AppTheme.red)
                }
                Text("æ ·æœ¬ \(sentiment.sampleCount) æ¡ï¼ŒæŒ‡æ•° \(sentiment.score >= 0 ? "+" : "")\(sentiment.score, specifier: "%.2f")")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textTertiary)
            } else {
                Text("å½“å‰èŒƒå›´å°šæœªå®Œæˆæƒ…ç»ªè®¡ç®—ã€‚ç”Ÿæˆ AI æŠ¥å‘Šåä¼šæ˜¾ç¤ºæ¨¡å‹ç»“æœã€‚")
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
        InsightPanel(title: "å…³æ³¨ä¸»é¢˜", icon: "tag", tint: AppTheme.yellow) {
            if settingsStore.settings.keywords.isEmpty {
                Text("å°šæœªé…ç½®å…³é”®è¯ï¼Œå½“å‰å±•ç¤ºå…¨éƒ¨è®¢é˜…å†…å®¹ã€‚")
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                FlowLayout(items: settingsStore.settings.keywords)
            }
        }
    }

    private var aiCard: some View {
        InsightPanel(title: "AI æ´å¯Ÿ", icon: "sparkles", tint: AppTheme.cyan) {
            VStack(alignment: .leading, spacing: 10) {
                let aiReady = settingsStore.settings.ai.enabled && settingsStore.settings.aiAnalysis.enabled
                Text(aiReady ? "AI åˆ†æå·²å¯ç”¨" : "AI åˆ†ææœªå¯ç”¨")
                    .font(AppTheme.headlineFont)
                    .foregroundStyle(AppTheme.textPrimary)
                Text(aiReady ? "ç”Ÿæˆåï¼Œå®Œæ•´æŠ¥å‘Šä¼šæ˜¾ç¤ºåœ¨æœ¬é¡µä¸‹æ–¹ã€‚" : "è¯·åŒæ—¶å¯ç”¨ AI åˆ†æä¸ç»“æ„åŒ–æŠ¥å‘Šåˆ†æï¼Œå¹¶é…ç½® API Base URLã€Key å’Œæ¨¡å‹ã€‚")
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textSecondary)
                if aiReady {
                    Button {
                        generateCurrentAIReport()
                    } label: {
                        Label(isGenerating ? "æ­£åœ¨ç”Ÿæˆå¹¶åˆ†æ" : "ç”Ÿæˆå¹¶å±•ç¤º \(selectedWindow.title) æŠ¥å‘Š", systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(AccentButtonStyle())
                    .disabled(isGenerating)
                    Label("æŠ¥å‘Šç”Ÿæˆæ—¶ä¼šæŒ‰ç»“æ„åŒ– JSON ä¿å­˜æƒ…ç»ªæ¯”ä¾‹ã€å¼±ä¿¡å·å’Œç­–ç•¥å»ºè®®ã€‚", systemImage: "info.circle")
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
        }
    }

    private func generateCurrentAIReport() {
        guard !isGenerating else { return }
        guard !windowItems.isEmpty || !windowHotlistItems.isEmpty else {
            actionFeedback = .failure("å½“å‰èŒƒå›´æ²¡æœ‰å¯åˆ†æçš„æ•°æ®ï¼Œè¯·å…ˆåˆ·æ–°çƒ­æ¦œæˆ– RSS")
            return
        }
        isGenerating = true
        actionFeedback = .progress("æ­£åœ¨ç”Ÿæˆç»“æ„åŒ– AI æ´å¯ŸæŠ¥å‘Š")
        reportStore.errorMessage = nil
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
            if let generated = await reportStore.latestGeneratedDetail() {
                latestAnalysis = generated.aiAnalysis
                if let failure = generated.aiAnalysis?.failureMessage, !failure.isEmpty {
                    actionFeedback = .failure("æŠ¥å‘Šå·²ä¿å­˜ï¼Œä½† AI åˆ†æå¤±è´¥ï¼š\(failure)")
                } else if generated.aiAnalysis?.hasContent == true {
                    actionFeedback = .success("AI æ´å¯ŸæŠ¥å‘Šå·²ç”Ÿæˆå¹¶ä¿å­˜")
                } else {
                    actionFeedback = .failure("æŠ¥å‘Šå·²ä¿å­˜ï¼Œä½†æ²¡æœ‰ç”Ÿæˆå¯ç”¨çš„ AI åˆ†æï¼Œè¯·æ£€æŸ¥ AI é…ç½®")
                }
            } else {
                await loadLatestAnalysis()
                actionFeedback = .failure(reportStore.errorMessage ?? "æŠ¥å‘Šç”Ÿæˆå¤±è´¥ï¼Œè¯·ç¨åé‡è¯•")
            }
        }
    }

    private var latestAIReportCard: some View {
        InsightPanel(title: "AI åˆ†ææŠ¥å‘Š", icon: "doc.text.magnifyingglass", tint: AppTheme.brandIndigo) {
            if let analysis = (reportStore.latestAIAnalysis ?? latestAnalysis), let failure = analysis.failureMessage, !failure.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("æœ¬æ¬¡ AI åˆ†ææœªç”Ÿæˆ").font(AppTheme.headlineFont).foregroundStyle(AppTheme.red)
                    Text(failure).font(AppTheme.bodyFont).foregroundStyle(AppTheme.textSecondary)
                    Text("è¯·æ£€æŸ¥ AI å¼€å…³ã€API Base URLã€API Keyã€æ¨¡å‹åç§°å’Œæç¤ºè¯æ–‡ä»¶ã€‚")
                        .font(AppTheme.captionFont).foregroundStyle(AppTheme.textTertiary)
                }
            } else if let analysis = (reportStore.latestAIAnalysis ?? latestAnalysis), analysis.hasContent {
                VStack(alignment: .leading, spacing: 14) {
                    if let content = analysis.coreTrends ?? analysis.content, !content.isEmpty {
                        insightReportBlock(title: "æ ¸å¿ƒçƒ­ç‚¹æ€åŠ¿", content: content)
                    }
                    if let content = analysis.sentimentControversy, !content.isEmpty {
                        insightReportBlock(title: "èˆ†è®ºé£å‘äº‰è®®", content: content)
                    }
                    if let content = analysis.signals, !content.isEmpty {
                        insightReportBlock(title: "å¼‚åŠ¨ä¸å¼±ä¿¡å·", content: content)
                    }
                    if let content = analysis.rssInsights, !content.isEmpty {
                        insightReportBlock(title: "RSS æ·±åº¦æ´å¯Ÿ", content: content)
                    }
                    if let content = analysis.recommendation, !content.isEmpty {
                        insightReportBlock(title: "ç ”åˆ¤ç­–ç•¥å»ºè®®", content: content)
                    }
                    if !analysis.standaloneSummaries.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ç‹¬ç«‹æºç‚¹é€Ÿè§ˆ")
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
                        if let report = reportStore.reports.max(by: { $0.generatedAt < $1.generatedAt }) {
                            ReportDetailView(reportID: report.id)
                        }
                    } label: {
                        Label("æŸ¥çœ‹å®Œæ•´æŠ¥å‘Š", systemImage: "arrow.up.right")
                    }
                    .buttonStyle(OutlineButtonStyle())
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    if let latest = reportStore.reports.max(by: { $0.generatedAt < $1.generatedAt }) {
                        Text("æœ€è¿‘æŠ¥å‘Šå°šæœªç”Ÿæˆ AI åˆ†æ")
                            .font(AppTheme.bodyFont)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("æŠ¥å‘Šå·²ä¿å­˜ï¼Œä½† AI åˆ†æéœ€è¦å•ç‹¬æ‰§è¡Œã€‚ç‚¹å‡»ä¸‹æ–¹æŒ‰é’®å³å¯ä¸ºè¿™ä»½æŠ¥å‘Šè¡¥ç”Ÿæˆã€‚")
                            .font(AppTheme.captionFont)
                            .foregroundStyle(AppTheme.textSecondary)
                        Button {
                            Task { await reportStore.generateAIAnalysis(for: latest.id, settings: settingsStore.settings) }
                        } label: {
                            Label(reportStore.isGenerating ? "æ­£åœ¨ç”Ÿæˆ AI åˆ†æ" : "ä¸ºæœ€è¿‘æŠ¥å‘Šç”Ÿæˆ AI åˆ†æ", systemImage: "sparkles")
                        }
                        .buttonStyle(AccentButtonStyle())
                        .disabled(reportStore.isGenerating)
                    } else {
                        Text("å½“å‰è¿˜æ²¡æœ‰ä¿å­˜çš„æŠ¥å‘Šã€‚è¯·å…ˆç”Ÿæˆä¸€ä»½æŠ¥å‘Šã€‚")
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
        InsightPanel(title: "è‡ªç„¶è¯­è¨€æŸ¥è¯¢", icon: "bubble.left.and.text.bubble.right", tint: AppTheme.cyan) {
            TextField("ä¾‹å¦‚ï¼šæœ€è¿‘ä¸€å‘¨ç§‘æŠ€åœˆæœ‰ä»€ä¹ˆå¤§äº‹ï¼Ÿ", text: $queryText, axis: .vertical)
            Button {
                let question = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !question.isEmpty else { return }
                isQuerying = true
                actionFeedback = .progress("æ­£åœ¨æŸ¥è¯¢æœ¬æœºæƒ…æŠ¥ä¸å¼•ç”¨æ¥æº")
                Task {
                    defer { isQuerying = false }
                    do {
                        queryResult = try await AIService().query(question: question, hotlistItems: windowHotlistItems, rssItems: windowItems, settings: settingsStore.settings)
                        actionFeedback = .success("æŸ¥è¯¢å®Œæˆï¼Œå¼•ç”¨æ¥æºå·²å…³è”")
                    } catch {
                        actionFeedback = .failure("æŸ¥è¯¢å¤±è´¥ï¼š\(error.localizedDescription)")
                    }
                }
            } label: {
                Label(isQuerying ? "æŸ¥è¯¢ä¸­" : "æŸ¥è¯¢æœ¬åœ°æƒ…æŠ¥", systemImage: "arrow.up.circle")
            }
            .buttonStyle(OutlineButtonStyle())
            .disabled(isQuerying)
            if let result = queryResult {
                Text(result.answer)
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textPrimary)
                ForEach(result.citations) { citation in
                    if let url = citation.url {
                        Link("å¼•ç”¨ï¼š\(citation.source) Â· \(citation.title)", destination: url)
                            .font(AppTheme.captionFont)
                            .foregroundStyle(AppTheme.cyan)
                    }
                }
            }
        }
    }

    private var hotNewsInsightCard: some View {
        InsightPanel(title: "çƒ­æ¦œè¶‹åŠ¿", icon: "chart.line.uptrend.xyaxis", tint: AppTheme.pink) {
            if hotNewsStore.topics.isEmpty {
                Text("æš‚æ— è·¨å¹³å°ä¸»é¢˜æ•°æ®ã€‚")
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
                    Text(topic.platforms.joined(separator: " Â· "))
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textTertiary)
                    if let duration = topic.duration, duration >= 3600 {
                        Text("æŒç»­ä¸Šæ¦œ \(Int(duration / 3600)) å°æ—¶")
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
        InsightPanel(title: "çƒ­ç‚¹å¼‚åŠ¨", icon: "bolt.fill", tint: AppTheme.red) {
            if hotNewsStore.anomalies.isEmpty {
                Text("æš‚æ— è¾¾åˆ°é˜ˆå€¼çš„çƒ­ç‚¹å¼‚åŠ¨ã€‚")
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
                                    Text(anomaly.platforms.joined(separator: " Â· ")).font(AppTheme.captionFont).foregroundStyle(AppTheme.textTertiary)
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
                        hotNewsOverview
                        radarStateFilters
                        hotNewsFilters
                        if !hotNewsStore.sourceFailures.isEmpty {
                            SourceHealthBanner(title: "éƒ¨åˆ†çƒ­æ¦œå¹³å°æš‚ä¸å¯ç”¨", detail: hotNewsStore.sourceFailures.joined(separator: "ã€"), tint: AppTheme.yellow)
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
                                        Text("æš‚æ— çƒ­æ¦œç¼“å­˜")
                                            .font(AppTheme.headlineFont)
                                            .foregroundStyle(AppTheme.textPrimary)
                                        Text("è¿›å…¥çƒ­æ¦œé¡µåˆ·æ–°åï¼Œè¿™é‡Œä¼šæ˜¾ç¤ºå®æ—¶ä¿¡å·")
                                            .font(AppTheme.captionFont)
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }
                                    Spacer(minLength: 0)
                                }
                                Button {
                                    Task { await hotNewsStore.refresh(settings: settingsStore.settings, latest: true) }
                                } label: {
                                    Label("ç«‹å³åˆ·æ–°", systemImage: "arrow.clockwise")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(AccentButtonStyle())
                            }
                            .padding(16)
                            .intelligenceCard(tint: AppTheme.yellow, cornerRadius: 16)
                        } else {
                            if hotNewsStore.radarTopics.isEmpty {
                                FeatureEmptyState(icon: "line.3.horizontal.decrease.circle", title: "æ²¡æœ‰ç¬¦åˆæ¡ä»¶çš„è¶‹åŠ¿", message: "æ¢å¤å…¨éƒ¨ç­›é€‰ï¼ŒæŸ¥çœ‹å½“å‰çœŸå®æ’åå¿«ç…§ã€‚", actionTitle: "æ¢å¤å…¨éƒ¨ç­›é€‰") {
                                    withAnimation(AppAnimation.standard) { hotNewsStore.selectedRadarFilter = .all }
                                }
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
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("é›·è¾¾")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .navigationDestination(for: HotNewsTopic.self) { topic in
                HotNewsTrendView(topic: topic)
            }
            .refreshable { await hotNewsStore.refresh(settings: settingsStore.settings) }
            .sensoryFeedback(.selection, trigger: hotNewsStore.selectedRadarFilter)
            .task { await hotNewsStore.refresh(settings: settingsStore.settings, showError: false) }
            .alert("çƒ­æ¦œåˆ·æ–°", isPresented: Binding(get: { hotNewsStore.errorMessage != nil }, set: { if !$0 { hotNewsStore.errorMessage = nil } })) {
                Button("é‡è¯•åˆ·æ–°") { Task { await hotNewsStore.refresh(settings: settingsStore.settings) } }
                Button("ç¡®å®š", role: .cancel) { hotNewsStore.errorMessage = nil }
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
            PremiumMetricCard(value: "\(hotNewsStore.items.count)", label: "çƒ­ç‚¹", icon: "flame.fill", tint: AppTheme.yellow)
            PremiumMetricCard(value: "\(Set(hotNewsStore.items.map(\.platformID)).count)", label: "å¹³å°", icon: "square.grid.2x2", tint: AppTheme.brandCyan)
            PremiumMetricCard(value: "\(hotNewsStore.sourceFailures.count)", label: "å¼‚å¸¸", icon: "exclamationmark.triangle", tint: hotNewsStore.sourceFailures.isEmpty ? AppTheme.green : AppTheme.yellow)
        }
    }

    private var radarSummary: some View {
        PremiumPanel(tint: AppTheme.brandCyan) {
            HStack(spacing: 18) {
                RadarDecoration(count: hotNewsStore.items.count)
                    .frame(width: 150, height: 170)
                VStack(alignment: .leading, spacing: 10) {
                    Text("å®æ—¶ä¿¡å·æ‰«æ")
                        .font(AppTheme.headlineFont)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(hotNewsStore.lastUpdated.map { "æ›´æ–°äº \($0, format: .dateTime.hour().minute())" } ?? "ç­‰å¾…é¦–æ¬¡åˆ·æ–°")
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textSecondary)
                    PremiumStatusLine(title: "æ•°æ®å¹³å°", detail: "\(Set(hotNewsStore.items.map(\.platformID)).count) ä¸ª", isGood: !hotNewsStore.items.isEmpty)
                    PremiumStatusLine(title: "æ’åè½¨è¿¹", detail: hotNewsStore.items.contains { $0.previousRank != nil } ? "å¯ç”¨" : "ç§¯ç´¯ä¸­", isGood: hotNewsStore.items.contains { $0.previousRank != nil })
                }
            }
        }
    }

    private var hotNewsFilters: some View {
        let platforms = Dictionary(hotNewsStore.items.map { ($0.platformID, $0.platformName) }, uniquingKeysWith: { first, _ in first }).sorted { $0.value < $1.value }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FeedFilterChip(title: "å…¨éƒ¨å¹³å°", isSelected: hotNewsStore.selectedPlatformID == nil) { hotNewsStore.selectedPlatformID = nil }
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
                Text("å®æ—¶çƒ­ç‚¹é›·è¾¾")
                    .font(AppTheme.headlineFont)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("è·¨å¹³å°æ’åä¸çœŸå®å˜åŒ–è¶‹åŠ¿")
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
        guard let item = topic.items.min(by: { $0.rank < $1.rank }), let previous = item.previousRank else { return "æ–°" }
        let delta = previous - item.rank
        return delta == 0 ? "â€”" : delta > 0 ? "â†‘ \(delta)" : "â†“ \(abs(delta))"
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
                    Text(topic.platforms.joined(separator: " Â· "))
                    Text("Â·")
                    Text("çƒ­åº¦å®æ—¶")
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
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .intelligenceCard(tint: trendTint, cornerRadius: 16)
    }
}

struct HotNewsTrendView: View {
    @EnvironmentObject private var hotNewsStore: HotNewsStore
    let topic: HotNewsTopic
    @State private var snapshots: [RankSnapshot] = []
    @State private var isFollowing = false
    @State private var selectedRange = 7

    private var visibleSnapshots: [RankSnapshot] {
        guard let start = Calendar.current.date(byAdding: .day, value: -selectedRange, to: Date()) else { return snapshots }
        return snapshots.filter { $0.capturedAt >= start }
    }

    private var trendScore: Int {
        guard let first = visibleSnapshots.first, let last = visibleSnapshots.last else { return 0 }
        return max(-100, min(100, (first.rank - last.rank) * 8))
    }

    var body: some View {
        ZStack {
            IntelligenceScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageVisualBanner(assetName: "TrendRadar-RadarHero", height: 120)
                    Text(topic.title)
                        .font(AppTheme.titleFont)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(topic.platforms.joined(separator: " Â· "))
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("è·¨å¹³å°å‡ºç° Â· ç‚¹å‡»æŸ¥çœ‹æ’åè½¨è¿¹")
                        .font(AppTheme.metadataFont)
                        .foregroundStyle(AppTheme.textTertiary)
                    trendMetrics
                    Picker("æ—¶é—´èŒƒå›´", selection: $selectedRange) {
                        Text("7 å¤©").tag(7); Text("30 å¤©").tag(30); Text("90 å¤©").tag(90)
                    }.pickerStyle(.segmented)
                    TrendChart(snapshots: visibleSnapshots)
                        .padding(16)
                        .intelligenceCard(tint: AppTheme.electricBlue, cornerRadius: 18)
                    sourceDistribution
                        .padding(16)
                        .intelligenceCard(tint: AppTheme.brandIndigo, cornerRadius: 18)
                    ForEach(topic.items) { item in
                        HotNewsTrendRow(item: item)
                    }
                    if !visibleSnapshots.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            PremiumSectionHeader(title: "æ—¶é—´çº¿äº‹ä»¶", subtitle: "çœŸå®æ’åå¿«ç…§", icon: "clock.arrow.circlepath", tint: AppTheme.brandMagenta)
                            ForEach(visibleSnapshots.reversed()) { snapshot in
                                HStack(spacing: 10) {
                                    Circle().fill(AppTheme.brandMagenta).frame(width: 8, height: 8)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(snapshot.sourceName) æ’å #\(snapshot.rank)").font(AppTheme.headlineFont)
                                        Text(snapshot.capturedAt.formatted(date: .abbreviated, time: .shortened)).font(AppTheme.captionFont).foregroundStyle(AppTheme.textTertiary)
                                    }
                                }
                            }
                        }.padding(16).intelligenceCard(tint: AppTheme.brandMagenta, cornerRadius: 18)
                    }
                }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
        .navigationTitle("æ’åæ—¶é—´çº¿")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isFollowing.toggle()
                    Task { await hotNewsStore.toggleFavorite(for: topic) }
                } label: {
                    ToolbarIconLabel(systemName: isFollowing ? "star.fill" : "star", label: isFollowing ? "å–æ¶ˆå…³æ³¨ä¸»é¢˜" : "å…³æ³¨ä¸»é¢˜", tint: isFollowing ? AppTheme.yellow : AppTheme.textPrimary)
                }
            }
        }
        .task {
            isFollowing = topic.items.contains(where: \.isFavorite)
            snapshots = await hotNewsStore.rankSnapshots(for: topic.id)
     ómí¢G§²ÚîÆ­yÑY¥•Üì(€€€±•ĞÍ¹…ÁÍ¡½ÑÌèmI…¹­M¹…ÁÍ¡½Ñt((€€€Ù…È‰½‘äèÍ½µ”Y¥•Üì(€€€€€€€iMÑ…¬ì(€€€€€€€€€€€I½Õ¹‘•‘I•Ñ…¹±”¡½É¹•ÉI…‘¥ÕÌè€ÄØ°ÍÑå±”è€¹½¹Ñ¥¹Õ½ÕÌ¤¹™¥±°¡ÁÁQ¡•µ”¹…É¤(€€€€€€€€€€€¥˜Í¹…ÁÍ¡½ÑÌ¹½Õ¹Ğ€øô€Èì(€€€€€€€€€€€€€€€¡…ÉĞ¡Í¹…ÁÍ¡½ÑÌ¤ìÍ¹…ÁÍ¡½Ğ¥¸(€€€€€€€€€€€€€€€€€€€1¥¹•5…É¬¡àè€¹Ù…±Õ” ‹š^Û¦^Ğˆ°Í¹…ÁÍ¡½Ğ¹…ÁÑÕÉ•‘Ğ¤°äè€¹Ù…±Õ” ‹š:K–B4ˆ°Í¹…ÁÍ¡½Ğ¹É…¹¬¤¤(€€€€€€€€€€€€€€€€€€€€€€€€¹™½É•É½Õ¹‘MÑå±”¡‰äè€¹Ù…±Õ” ‹–æÏ–>Àˆ°Í¹…ÁÍ¡½Ğ¹Í½ÕÉ•9…µ”¤¤(€€€€€€€€€€€€€€€€€€€€€€€€¹±¥¹•MÑå±”¡MÑÉ½­•MÑå±”¡±¥¹•]¥‘Ñ è€Ì°±¥¹•…Àè€¹É½Õ¹°±¥¹•)½¥¸è€¹É½Õ¹¤¤(€€€€€€€€€€€€€€€€€€€A½¥¹Ñ5…É¬¡àè€¹Ù…±Õ” ‹š^Û¦^Ğˆ°Í¹…ÁÍ¡½Ğ¹…ÁÑÕÉ•‘Ğ¤°äè€¹Ù…±Õ” ‹š:K–B4ˆ°Í¹…ÁÍ¡½Ğ¹É…¹¬¤¤(€€€€€€€€€€€€€€€€€€€€€€€€¹™½É•É½Õ¹‘MÑå±”¡‰äè€¹Ù…±Õ” ‹–æÏ–>Àˆ°Í¹…ÁÍ¡½Ğ¹Í½ÕÉ•9…µ”¤¤(€€€€€€€€€€€€€€€ô(€€€€€€€€€€€€€€€€¹¡…ÉÑeM…±”¡‘½µ…¥¸è€¹…ÕÑ½µ…Ñ¥Œ¡¥¹±Õ‘•Íi•É¼è™…±Í”°É•Ù•ÉÍ•èÑÉÕ”¤¤(€€€€€€€€€€€€€€€€¹¡…ÉÑeá¥Ììá¥Í5…É­Ì¡Á½Í¥Ñ¥½¸è€¹±•…‘¥¹œ¤ô(€€€€€€€€€€€€€€€€¹¡…ÉÑaá¥Ììá¥Í5…É­Ì¡Ù…±Õ•Ìè€¹…ÕÑ½µ…Ñ¥Œ¡‘•Í¥É•‘½Õ¹Ğè€Ğ¤¤ô(€€€€€€€€€€€€€€€€¹Á…‘‘¥¹œ ÄĞ¤(€€€€€€€€€€€€€€€YMÑ…¬ì(€€€€€€€€€€€€€€€€€€€MÁ…•È ¤(€€€€€€€€€€€€€€€€€€€Q•áĞ ‹š:K–B7¢Ú+¦vƒ–&7¾ò3šnËêÿ¢Ú+š:—¢şG¦†Û¦ ˆ¤(€€€€€€€€€€€€€€€€€€€€€€€€¹™½¹Ğ¡ÁÁQ¡•µ”¹…ÁÑ¥½¹½¹Ğ¤(€€€€€€€€€€€€€€€€€€€€€€€€¹™½É•É½Õ¹‘MÑå±”¡ÁÁQ¡•µ”¹Ñ•áÑQ•ÉÑ¥…Éä¤(€€€€€€€€€€€€€€€€€€€€€€€€¹Á…‘‘¥¹œ ¹‰½ÑÑ½´°€ÄÀ¤(€€€€€€€€€€€€€€€ô(€€€€€€€€€€€ô•±Í”ì(€€€€€€€€€€€€€€€Q•áĞ ‹šVÃš6»¿Ò¿’â·¾ò3¢Ï–ÂG¦r¢š’â“š²‡¦¦nˆ¤(€€€€€€€€€€€€€€€€€€€€¹™½¹Ğ¡ÁÁQ¡•µ”¹‰½‘å½¹Ğ¤(€€€€€€€€€€€€€€€€€€€€¹™½É•É½Õ¹‘MÑå±”¡ÁÁQ¡•µ”¹Ñ•áÑM•½¹‘…Éä¤(€€€€€€€€€€€ô(€€€€€€€ô(€€€€€€€€¹™É…µ”¡¡•¥¡Ğè€ÈÈÀ¤(€€€ô)ô()ÁÉ¥Ù…Ñ”•áÑ•¹Í¥½¸I…‘…É¥±Ñ•Èì(€€€Ù…ÈÑ¥Ñ±”èMÑÉ¥¹œì(€€€€€€€Íİ¥Ñ Í•±˜ì(€€€€€€€…Í”€¹…±°èÉ•ÑÕÉ¸€‹–£¦ ˆ(€€€€€€€…Í”€¹É¥Í¥¹œèÉ•ÑÕÉ¸€‹’â+–6ˆ(€€€€€€€…Í”€¹¹•ÜèÉ•ÑÕÉ¸€‹šZÃ¢şlˆ(€€€€€€€…Í”€¹ÍÕÍÑ…¥¹•èÉ•ÑÕÉ¸€‹š2î´ˆ(€€€€€€€…Í”€¹™½±±½İ¥¹œèÉ•ÑÕÉ¸€‹–ÏšÎ ˆ(€€€€€€€ô(€€€ô((€€€Ù…ÈÍåÍÑ•µ%µ…”èMÑÉ¥¹œì(€€€€€€€Íİ¥Ñ Í•±˜ì(€€€€€€€…Í”€¹…±°èÉ•ÑÕÉ¸€‰±¥¹”¸Ì¹¡½É¥é½¹Ñ…°¹‘•É•…Í”ˆ(€€€€€€€…Í”€¹É¥Í¥¹œèÉ•ÑÕÉ¸€‰…ÉÉ½Ü¹ÕÀ¹É¥¡Ğˆ(€€€€€€€…Í”€¹¹•ÜèÉ•ÑÕÉ¸€‰ÍÁ…É­±•Ìˆ(€€€€€€€…Í”€¹ÍÕÍÑ…¥¹•èÉ•ÑÕÉ¸€‰±½¬ˆ(€€€€€€€…Í”€¹™½±±½İ¥¹œèÉ•ÑÕÉ¸€‰ÍÑ…Èˆ(€€€€€€€ô(€€€ô)ô()ÍÑÉÕĞ…Ù½É¥Ñ•ÍY¥•ÜèY¥•Üì(€€€¹Ù¥É½¹µ•¹Ñ=‰©•ĞÁÉ¥Ù…Ñ”Ù…ÈÍÑ½É”è9•İÍMÑ½É”(€€€¹Ù¥É½¹µ•¹Ñ=‰©•ĞÁÉ¥Ù…Ñ”Ù…È¡½Ñ9•İÍMÑ½É”è!½Ñ9•İÍMÑ½É”(€€€¹Ù¥É½¹µ•¹Ñ=‰©•ĞÁÉ¥Ù…Ñ”Ù…ÈÉ•Á½ÉÑMÑ½É”èI•Á½ÉÑMÑ½É”(€€€¹Ù¥É½¹µ•¹Ñ=‰©•ĞÁÉ¥Ù…Ñ”Ù…È…É¡¥Ù•MÑ½É”èÉ¡¥Ù•MÑ½É”(€€€MÑ…Ñ”ÁÉ¥Ù…Ñ”Ù…ÈÍ¡½İ¥¹M•ÑÑ¥¹Ì€ô™…±Í”((€€€Ù…È‰½‘äèÍ½µ”Y¥•Üì(€€€€€€€9…Ù¥…Ñ¥½¹MÑ…¬ì(€€€€€€€€€€€iMÑ…¬ì(€€€€€€€€€€€€€€€%¹Ñ•±±¥•¹•MÉ••¹	…­É½Õ¹ ¤(€€€€€€€€€€€€€€€MÉ½±±Y¥•Üì(€€€€€€€€€€€€€€€€€€€1…éåYMÑ…¬¡…±¥¹µ•¹Ğè€¹±•…‘¥¹œ°ÍÁ…¥¹œè€ÄØ¤ì(€€€€€€€€€€€€€€€€€€€€€€€…É¡¥Ù•¥±Ñ•È(€€€€€€€€€€€€€€€€€€€€€€€€¥˜…É¡¥Ù•MÑ½É”¹™¥±Ñ•É•‘%Ñ•µÌ¹¥ÍµÁÑäì(€€€€€€€€€€€€€€€€€€€€€€€€€€€€•…ÑÕÉ•µÁÑåMÑ…Ñ”¡¥½¸è€‰…É¡¥Ù•‰½àˆ°Ñ¥Ñ±”è€‹¢ÖšZg–êO¢şcšb¿¦ëjˆ°µ•ÍÍ…”è€‹šRÛ¢^?¢Ú/–*ÿš"[š*—–F+¾ò3š"[–r£¢º‹¦b’â·–öKš†šZ®ƒ¾ò3–º’î³’òk–º'–£’şw–¶c–r£¢şg¦3ˆ¤(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€¹™É…µ”¡µ…á]¥‘Ñ è€¹¥¹™¥¹¥Ñä¤(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€¹Á…‘‘¥¹œ ¹Ñ½À°€ÌÈ¤(€€€€€€€€€€€€€€€€€€€€€€€ô•±Í”ì(€€€€€€€€€€€€€€€€€€€€€€€€€€€½É… ¡…É¡¥Ù•MÑ½É”¹™¥±Ñ•É•‘%Ñ•µÌ¤ìÉ•Í½ÕÉ”¥¸(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€9…Ù¥…Ñ¥½¹1¥¹¬¡Ù…±Õ”èÉ•Í½ÕÉ”¤ì(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€É¡¥Ù•I•Í½ÕÉ•I½Ü¡É•Í½ÕÉ”èÉ•Í½ÕÉ”¤(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€ô(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€¹‰ÕÑÑ½¹MÑå±” ¹Á±…¥¸¤(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€¹½¹Ñ•áÑ5•¹Ôì(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€M¡…É•1¥¹¬¡¥Ñ•´èÉ•Í½ÕÉ”¹Í¡…É•Q•áĞ¤ì1…‰•° ‹–"’ê¬ˆ°ÍåÍÑ•µ%µ…”è€‰ÍÅÕ…É”¹…¹¹…ÉÉ½Ü¹ÕÀˆ¤ô(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€	ÕÑÑ½¸¡É½±”è€¹‘•ÍÑÉÕÑ¥Ù”¤ìQ…Í¬ì…İ…¥Ğ…É¡¥Ù•MÑ½É”¹‘•±•Ñ”¡É•Í½ÕÉ”¤ôô±…‰•°èì(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€1…‰•° ‹ï–ë¢ÖšZg–êLˆ°ÍåÍÑ•µ%µ…”è€‰ÑÉ…Í ˆ¤(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€ô(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€ô(€€€€€€€€€€€€€€€€€€€€€€€€€€€ô(€€€€€€€€€€€€€€€€€€€€€€€ô(€€€€€€€€€€€€€€€€€€€ô(€€€€€€€€€€€€€€€€€€€€¹Á…‘‘¥¹œ ¹¡½É¥é½¹Ñ…°°€ÄØ¤(€€€€€€€€€€€€€€€€€€€€¹Á…‘‘¥¹œ ¹Ñ½À°€ÄÈ¤(€€€€€€€€€€€€€€€€€€€€¹Á…‘‘¥¹œ ¹‰½ÑÑ½´°€Èà¤(€€€€€€€€€€€€€€€ô(€€€€€€€€€€€ô(€€€€€€€€€€€€€¹¹…Ù¥…Ñ¥½¹Q¥Ñ±” ‹¢ÖšZg–êLˆ¤(€€€€€€€€€€€€¹¹…Ù¥…Ñ¥½¹	…ÉQ¥Ñ±•¥ÍÁ±…å5½‘” ¹¥¹±¥¹”¤(€€€€€€€€€€€€¹Ñ½½±‰…É	…­É½Õ¹¡ÁÁQ¡•µ”¹‰…­É½Õ¹°™½Èè€¹¹…Ù¥…Ñ¥½¹	…È¤(€€€€€€€€€€€€¹Ñ½½±‰…Èì(€€€€€€€€€€€€€€€Q½½±‰…É%Ñ•´¡Á±…•µ•¹Ğè€¹Ñ½Á	…ÉQÉ…¥±¥¹œ¤ì(€€€€€€€€€€€€€€€€€€€	ÕÑÑ½¸ìÍ¡½İ¥¹M•ÑÑ¥¹Ì€ôÑÉÕ”ô±…‰•°èì(€€€€€€€€€€€€€€€€€€€€€€€Q½½±‰…É%½¹1…‰•°¡ÍåÍÑ•µ9…µ”è€‰•…ÉÍ¡…Á”ˆ°±…‰•°è€‹¢ºûö¸ˆ¤(€€€€€€€€€€€€€€€€€€€ô(€€€€€€€€€€€€€€€€€€€€¹‰ÕÑÑ½¹MÑå±” ¹Á±…¥¸¤(€€€€€€€€€€€€€€€ô(€€€€€€€€€€€ô(€€€€€€€€€€€€¹Í•…É¡…‰±”¡Ñ•áĞè€‘…É¡¥Ù•MÑ½É”¹Í•…É¡Q•áĞ°ÁÉ½µÁĞè€‹šBsÒ‹š‚¦Šcšv—šêC–J3šFc¢šˆ¤(€€€€€€€€€€€€¹¹…Ù¥…Ñ¥½¹•ÍÑ¥¹…Ñ¥½¸¡™½ÈèÉ¡¥Ù•I•Í½ÕÉ”¹Í•±˜¤ìÉ•Í½ÕÉ”¥¸(€€€€€€€€€€€€€€€…É¡¥Ù••ÍÑ¥¹…Ñ¥½¸¡É•Í½ÕÉ”¤(€€€€€€€€€€€ô(€€€€€€€€€€€€¹Ñ…Í¬ì(€€€€€€€€€€€€€€€…İ…¥Ğ…É¡¥Ù•MÑ½É”¹Íå¹¡É½¹¥é”¡¹•İÌèÍÑ½É”¹¥Ñ•µÌ°Ñ½Á¥Ìè¡½Ñ9•İÍMÑ½É”¹Ñ½Á¥Ì°É•Á½ÉÑÌèÉ•Á½ÉÑMÑ½É”¹É•Á½ÉÑÌ¤(€€€€€€€€€€€ô(€€€€€€€€€€€€¹…±•ÉĞ ‹¢ÖšZg–êLˆ°¥ÍAÉ•Í•¹Ñ•è	¥¹‘¥¹œ¡•Ğèì…É¡¥Ù•MÑ½É”¹•ÉÉ½É5•ÍÍ…”€„ô¹¥°ô°Í•Ğèì¥˜€„Àì…É¡¥Ù•MÑ½É”¹•ÉÉ½É5•ÍÍ…”€ô¹¥°ôô¤¤ì(€€€€€€€€€€€€€€€	ÕÑÑ½¸ ‹†»–ºhˆ°É½±”è€¹…¹•°¤ì…É¡¥Ù•MÑ½É”¹•ÉÉ½É5•ÍÍ…”€ô¹¥°ô(€€€€€€€€€€€ôµ•ÍÍ…”èìQ•áĞ¡…É¡¥Ù•MÑ½É”¹•ÉÉ½É5•ÍÍ…”€üü€ˆˆ¤ô(€€€€€€€€€€€€¹Í¡••Ğ¡¥ÍAÉ•Í•¹Ñ•è€‘Í¡½İ¥¹M•ÑÑ¥¹Ì¤ìM•ÑÑ¥¹ÍY¥•Ü ¤ô(€€€€€€€ô(€€€ô((€€€ÁÉ¥Ù…Ñ”Ù…È…É¡¥Ù•!•…‘•ÈèÍ½µ”Y¥•Üì(€€€€€€€%¹Ñ•±±¥•¹•A…•!•…‘•È (€€€€€€€€€€€•å•‰É½Üè€‰1=01%	IIdˆ°(€€€€€€€€€€€Ñ¥Ñ±”è€‹’şw–¶crš¶¦7¢šj’ş‡–>Üˆ°(€€€€€€€€€€€ÍÕ‰Ñ¥Ñ±”è€‹šZÃ¦^ï¢Ú/–*ÿ–J3š*—–F+î’â–öKš†¾ò3¦j?š^ÛšÒ‹’â;–"’ê¬ˆ°(€€€€€€€€€€€¥½¸è€‰…É¡¥Ù•‰½à¹™¥±°ˆ(€€€€€€€€¤(€€€ô((€€€ÁÉ¥Ù…Ñ”Ù…È…É¡¥Ù•¥±Ñ•ÈèÍ½µ”Y¥•Üì(€€€€€€€MÉ½±±Y¥•Ü ¹¡½É¥é½¹Ñ…°°Í¡½İÍ%¹‘¥…Ñ½ÉÌè™…±Í”¤ì(€€€€€€€€€€€!MÑ…¬¡ÍÁ…¥¹œè€à¤ì(€€€€€€€€€€€€€€€••‘¥±Ñ•É¡¥À¡Ñ¥Ñ±”è€‹–£¦ p¡…É¡¥Ù•MÑ½É”¹¥Ñ•µÌ¹½Õ¹Ğ¤ˆ°¥ÍM•±•Ñ•è…É¡¥Ù•MÑ½É”¹Í•±•Ñ•‘-¥¹€ôô¹¥°¤ì…É¡¥Ù•MÑ½É”¹Í•±•Ñ•‘-¥¹€ô¹¥°ô(€€€€€€€€€€€€€€€½É… ¡É¡¥Ù•I•Í½ÕÉ•-¥¹¹…±±…Í•Ì°¥èp¹Í•±˜¤ì­¥¹¥¸(€€€€€€€€€€€€€€€€€€€±•Ğ½Õ¹Ğ€ô…É¡¥Ù•MÑ½É”¹¥Ñ•µÌ¹™¥±Ñ•Èì€À¹­¥¹€ôô­¥¹ô¹½Õ¹Ğ(€€€€€€€€€€€€€€€€€€€••‘¥±Ñ•É¡¥À¡Ñ¥Ñ±”è€‰p¡­¥¹¹Ñ¥Ñ±”¤p¡½Õ¹Ğ¤ˆ°¥ÍM•±•Ñ•è…É¡¥Ù•MÑ½É”¹Í•±•Ñ•‘-¥¹€ôô­¥¹¤ì…É¡¥Ù•MÑ½É”¹Í•±•Ñ•‘-¥¹€ô­¥¹ô(€€€€€€€€€€€€€€€ô(€€€€€€€€€€€ô(€€€€€€€ô(€€€€€€€€¹…•ÍÍ¥‰¥±¥Ñå1…‰•° ‹¢ÖšZgÆï–z/¶o¦$ˆ¤(€€€ô((€€€Y¥•İ	Õ¥±‘•È(€€€ÁÉ¥Ù…Ñ”™Õ¹Œ…É¡¥Ù••ÍÑ¥¹…Ñ¥½¸¡|É•Í½ÕÉ”èÉ¡¥Ù•I•Í½ÕÉ”¤€´øÍ½µ”Y¥•Üì(€€€€€€€Íİ¥Ñ É•Í½ÕÉ”¹­¥¹ì(€€€€€€€…Í”€¹ÉÍÌè(€€€€€€€€€€€¥˜±•Ğ¥Ñ•´€ôÍÑ½É”¹¥Ñ•µÌ¹™¥ÉÍĞ¡İ¡•É”èì€À¹¥€ôôÉ•Í½ÕÉ”¹É•Í½ÕÉ•%ô¤ì9•İÍ•Ñ…¥±Y¥•Ü¡¥Ñ•´è¥Ñ•´¤ô(€€€€€€€€€€€•±Í”ìÉ¡¥Ù•M¹…ÁÍ¡½ÑY¥•Ü¡É•Í½ÕÉ”èÉ•Í½ÕÉ”¤ô(€€€€€€€…Í”€¹¡½Ñ±¥ÍĞè(€€€€€€€€€€€¥˜±•ĞÑ½Á¥Œ€ô¡½Ñ9•İÍMÑ½É”¹Ñ½Á¥Ì¹™¥ÉÍĞ¡İ¡•É”èì€À¹¥€ôôÉ•Í½ÕÉ”¹É•Í½ÕÉ•%ô¤ì!½Ñ9•İÍQÉ•¹‘Y¥•Ü¡Ñ½Á¥ŒèÑ½Á¥Œ¤ô(€€€€€€€€€€€•±Í”ìÉ¡¥Ù•M¹…ÁÍ¡½ÑY¥•Ü¡É•Í½ÕÉ”èÉ•Í½ÕÉ”¤ô(€€€€€€€…Í”€¹É•Á½ÉĞè(€€€€€€€€€€€¥˜±•Ğ¥€ôUU%¡ÕÕ¥‘MÑÉ¥¹œèÉ•Í½ÕÉ”¹É•Í½ÕÉ•%¤°É•Á½ÉÑMÑ½É”¹É•Á½ÉÑÌ¹½¹Ñ…¥¹Ì¡İ¡•É”èì€À¹¥€ôô¥ô¤ìI•Á½ÉÑ•Ñ…¥±Y¥•Ü¡É•Á½ÉÑ%è¥¤ô(€€€€€€€€€€€•±Í”ìÉ¡¥Ù•M¹…ÁÍ¡½ÑY¥•Ü¡É•Í½ÕÉ”èÉ•Í½ÕÉ”¤ô(€€€€€€€ô(€€€ô)ô()ÁÉ¥Ù…Ñ”ÍÑÉÕĞÉ¡¥Ù•I•Í½ÕÉ•I½ÜèY¥•Üì(€€€¹Ù¥É½¹µ•¹Ğ¡p¹‘å¹…µ¥QåÁ•M¥é”¤ÁÉ¥Ù…Ñ”Ù…È‘å¹…µ¥QåÁ•M¥é”(€€€±•ĞÉ•Í½ÕÉ”èÉ¡¥Ù•I•Í½ÕÉ”((€€€Ù…È‰½‘äèÍ½µ”Y¥•Üì(€€€€€€€!MÑ…¬¡ÍÁ…¥¹œè€ÄÈ¤ì(€€€€€€€€€€€%µ…”¡ÍåÍÑ•µ9…µ”èÉ•Í½ÕÉ”¹­¥¹¹ÍåÍÑ•µ%µ…”¤(€€€€€€€€€€€€€€€€¹™½¹Ğ ¹ÍåÍÑ•´¡Í¥é”è€Äà°İ•¥¡Ğè€¹Í•µ¥‰½±¤¤(€€€€€€€€€€€€€€€€¹™½É•É½Õ¹‘MÑå±”¡ÁÁQ¡•µ”¹å…¸¤(€€€€€€€€€€€€€€€€¹™É…µ”¡İ¥‘Ñ è€ĞÈ°¡•¥¡Ğè€ĞÈ¤(€€€€€€€€€€€€€€€€¹‰…­É½Õ¹¡ÁÁQ¡•µ”¹å…¸¹½Á…¥Ñä À¸ÄÈ¤°¥¸èI½Õ¹‘•‘I•Ñ…¹±”¡½É¹•ÉI…‘¥ÕÌè€ÄÈ°ÍÑå±”è€¹½¹Ñ¥¹Õ½ÕÌ¤¤(€€€€€€€€€€€€€€€€¹…•ÍÍ¥‰¥±¥Ñå!¥‘‘•¸¡ÑÉÕ”¤(€€€€€€€€€€€YMÑ…¬¡…±¥¹µ•¹Ğè€¹±•…‘¥¹œ°ÍÁ…¥¹œè€Ô¤ì(€€€€€€€€€€€€€€€Q•áĞ¡É•Í½ÕÉ”¹Ñ¥Ñ±”¤¹™½¹Ğ¡ÁÁQ¡•µ”¹…É‘Q¥Ñ±•½¹Ğ¤¹™½É•É½Õ¹‘MÑå±”¡ÁÁQ¡•µ”¹Ñ•áÑAÉ¥µ…Éä¤¹±¥¹•1¥µ¥Ğ¡‘å¹…µ¥QåÁ•M¥é”¹¥Í•ÍÍ¥‰¥±¥ÑåM¥é”€ü€Ğ€è€È¤(€€€€€€€€€€€€€€€Q•áĞ ‰p¡É•Í½ÕÉ”¹­¥¹¹Ñ¥Ñ±”¤ƒ
Üp¡É•Í½ÕÉ”¹Í½ÕÉ”¤ˆ¤¹™½¹Ğ¡ÁÁQ¡•µ”¹…ÁÑ¥½¹½¹Ğ¤¹™½É•É½Õ¹‘MÑå±”¡ÁÁQ¡•µ”¹Ñ•áÑM•½¹‘…Éä¤¹±¥¹•1¥µ¥Ğ¡‘å¹…µ¥QåÁ•M¥é”¹¥Í•ÍÍ¥‰¥±¥ÑåM¥é”€ü€È€è€Ä¤(€€€€€€€€€€€€€€€Q•áĞ¡É•Í½ÕÉ”¹…ÁÑÕÉ•‘Ğ°™½Éµ…Ğè€¹É•±…Ñ¥Ù”¡ÁÉ•Í•¹Ñ…Ñ¥½¸è€¹¹…µ•¤¤¹™½¹Ğ¡ÁÁQ¡•µ”¹…ÁÑ¥½¹½¹Ğ¤¹™½É•É½Õ¹‘MÑå±”¡ÁÁQ¡•µ”¹Ñ•áÑQ•ÉÑ¥…Éä¤(€€€€€€€€€€€ô(€€€€€€€€€€€MÁ…•È¡µ¥¹1•¹Ñ è€Ğ¤(€€€€€€€€€€€%µ…”¡ÍåÍÑ•µ9…µ”è€‰¡•ÙÉ½¸¹É¥¡Ğˆ¤¹™½É•É½Õ¹‘MÑå±”¡ÁÁQ¡•µ”¹Ñ•áÑQ•ÉÑ¥…Éä¤¹…•ÍÍ¥‰¥±¥Ñå!¥‘‘•¸¡ÑÉÕ”¤(€€€€€€€ô(€€€€€€€€¹Á…‘‘¥¹œ ÄĞ¤(€€€€€€€€¹¥¹Ñ•±±¥•¹•…É¡Ñ¥¹ĞèÁÁQ¡•µ”¹å…¸°½É¹•ÉI…‘¥ÕÌè€ÄØ¤(€€€€€€€€¹…•ÍÍ¥‰¥±¥Ñå±•µ•¹Ğ¡¡¥±‘É•¸è€¹½µ‰¥¹”¤(€€€€€€€€¹…•ÍÍ¥‰¥±¥Ñå1…‰•° ‰p¡É•Í½ÕÉ”¹­¥¹¹Ñ¥Ñ±”§¾ò1p¡É•Í½ÕÉ”¹Ñ¥Ñ±”§¾ò3šv—šê@p¡É•Í½ÕÉ”¹Í½ÕÉ”¤ˆ¤(€€€ô)ô()ÁÉ¥Ù…Ñ”ÍÑÉÕĞÉ¡¥Ù•M¹…ÁÍ¡½ÑY¥•ÜèY¥•Üì(€€€±•ĞÉ•Í½ÕÉ”èÉ¡¥Ù•I•Í½ÕÉ”((€€€Ù…È‰½‘äèÍ½µ”Y¥•Üì(€€€€€€€%¹Ñ•±±¥•¹•A…”ì(€€€€€€€€€€€MÉ½±±Y¥•Üì(€€€€€€€€€€€€€€€YMÑ…¬¡…±¥¹µ•¹Ğè€¹±•…‘¥¹œ°ÍÁ…¥¹œè€ÄØ¤ì(€€€€€€€€€€€€€€€€€€€MÑ…ÑÕÍ	…‘”¡Ñ¥Ñ±”èÉ•Í½ÕÉ”¹­¥¹¹Ñ¥Ñ±”°ÍåÍÑ•µ%µ…”èÉ•Í½ÕÉ”¹­¥¹¹ÍåÍÑ•µ%µ…”°Ñ¥¹ĞèÁÁQ¡•µ”¹å…¸¤(€€€€€€€€€€€€€€€€€€€Q•áĞ¡É•Í½ÕÉ”¹Ñ¥Ñ±”¤¹™½¹Ğ¡ÁÁQ¡•µ”¹Ñ¥Ñ±•½¹Ğ¤¹™½É•É½Õ¹‘MÑå±”¡ÁÁQ¡•µ”¹Ñ•áÑAÉ¥µ…Éä¤(€€€€€€€€€€€€€€€€€€€Q•áĞ¡É•Í½ÕÉ”¹Í½ÕÉ”¤¹™½¹Ğ¡ÁÁQ¡•µ”¹…ÁÑ¥½¹½¹Ğ¤¹™½É•É½Õ¹‘MÑå±”¡ÁÁQ¡•µ”¹Ñ•áÑM•½¹‘…Éä¤(€€€€€€€€€€€€€€€€€€€¥˜±•ĞÍÕµµ…Éä€ôÉ•Í½ÕÉ”¹ÍÕµµ…ÉäìQ•áĞ¡ÍÕµµ…Éä¤¹™½¹Ğ¡ÁÁQ¡•µ”¹‰½‘å½¹Ğ¤¹™½É•É½Õ¹‘MÑå±”¡ÁÁQ¡•µ”¹Ñ•áÑM•½¹‘…Éä¤ô(€€€€€€€€€€€€€€€€€€€¥˜±•Ğ‰½‘ä€ôÉ•Í½ÕÉ”¹‰½‘ä°€…‰½‘ä¹¥ÍµÁÑäì(€€€€€€€€€€€€€€€€€€€€€€€Q•áĞ¡‰½‘ä¤¹™½¹Ğ¡ÁÁQ¡•µ”¹É•…‘¥¹½¹Ğ¤¹™½É•É½Õ¹‘MÑå±”¡ÁÁQ¡•µ”¹Ñ•áÑM•½¹‘…Éä¤¹±¥¹•MÁ…¥¹œ Ø¤(€€€€€€€€€€€€€€€€€€€ô(€€€€€€€€€€€€€€€€€€€YMÑ…¬¡…±¥¹µ•¹Ğè€¹±•…‘¥¹œ°ÍÁ…¥¹œè€ÄÀ¤ì(€€€€€€€€€€€€€€€€€€€€€€€1…‰•° ‹–ŞË–öKš†¾ò#’â7–>¿–>c¾ò$ˆ°ÍåÍÑ•µ%µ…”è€‰±½¬¹Í¡¥•±¹™¥±°ˆ¤¹™½É•É½Õ¹‘MÑå±”¡ÁÁQ¡•µ”¹‰É…¹‘5…•¹Ñ„¤(€€€€€€€€€€€€€€€€€€€€€€€1…‰•±•‘½¹Ñ•¹Ğ ‹––ºçš^Û¦^Ğˆ°Ù…±Õ”èÉ•Í½ÕÉ”¹…ÁÑÕÉ•‘Ğ¹™½Éµ…ÑÑ•¡‘…Ñ”è€¹…‰‰É•Ù¥…Ñ•°Ñ¥µ”è€¹Í¡½ÉÑ•¹•¤¤(€€€€€€€€€€€€€€€€€€€€€€€1…‰•±•‘½¹Ñ•¹Ğ ‹–öKš†š^Û¦^Ğˆ°Ù…±Õ”è€¡É•Í½ÕÉ”¹…É¡¥Ù•‘Ğ€üüÉ•Í½ÕÉ”¹…ÁÑÕÉ•‘Ğ¤¹™½Éµ…ÑÑ•¡‘…Ñ”è€¹…‰‰É•Ù¥…Ñ•°Ñ¥µ”è€¹Í¡½ÉÑ•¹•¤¤(€€€€€€€€€€€€€€€€€€€€€€€1…‰•±•‘½¹Ñ•¹Ğ ‹–ş¯Ÿ&#šr°ˆ°Ù…±Õ”èÉ•Í½ÕÉ”¹Í¹…ÁÍ¡½ÑY•ÉÍ¥½¸€üü€‹š^Ÿ& ˆ¤(€€€€€€€€€€€€€€€€€€€€€€€¥˜±•ĞÍ¥é”€ôÉ•Í½ÕÉ”¹½¹Ñ•¹ÑM¥é”ì1…‰•±•‘½¹Ñ•¹Ğ ‹––ºç–’Ÿ–Â<ˆ°Ù…±Õ”è	åÑ•½Õ¹Ñ½Éµ…ÑÑ•È¹ÍÑÉ¥¹œ¡™É½µ	åÑ•½Õ¹Ğè%¹ĞØĞ¡Í¥é”¤°½Õ¹ÑMÑå±”è€¹™¥±”¤¤ô(€€€€€€€€€€€€€€€€€€€€€€€¥˜±•Ğ¡•­ÍÕ´€ôÉ•Í½ÕÉ”¹¡•­ÍÕ´ì1…‰•±•‘½¹Ñ•¹Ğ ‰M!´ÈÔØˆ°Ù…±Õ”èMÑÉ¥¹œ¡¡•­ÍÕ´¹ÁÉ•™¥à ÄÈ¤¤€¬€‹Š˜ˆ¤ô(€€€€€€€€€€€€€€€€€€€ô(€€€€€€€€€€€€€€€€€€€€¹™½¹Ğ¡ÁÁQ¡•µ”¹…ÁÑ¥½¹½¹Ğ¤(€€€€€€€€€€€€€€€€€€€€¹Á…‘‘¥¹œ ÄØ¤(€€€€€€€€€€€€€€€€€€€€¹¥¹Ñ•±±¥•¹•…É¡Ñ¥¹ĞèÁÁQ¡•µ”¹‰É…¹‘5…•¹Ñ„°½É¹•ÉI…‘¥ÕÌè€ÄØ¤(€€€€€€€€€€€€€€€€€€€¥˜±•ĞÕÉ°€ôÉ•Í½ÕÉ”¹ÕÉ°ì1¥¹¬¡‘•ÍÑ¥¹…Ñ¥½¸èÕÉ°¤ì1…‰•° ‹š&O–ò–:šZˆ°ÍåÍÑ•µ%µ…”è€‰…ÉÉ½Ü¹ÕÀ¹É¥¡Ğˆ¤ô¹‰ÕÑÑ½¹MÑå±”¡=ÕÑ±¥¹•	ÕÑÑ½¹MÑå±” ¤¤ô(€€€€€€€€€€€€€€€€€€€M¡…É•1¥¹¬¡¥Ñ•´èÉ•Í½ÕÉ”¹Í¡…É•Q•áĞ¤ì1…‰•° ‹–"’ê¯¢ÖšZdˆ°ÍåÍÑ•µ%µ…”è€‰ÍÅÕ…É”¹…¹¹…ÉÉ½Ü¹ÕÀˆ¤¹™É…µ”¡µ…á]¥‘Ñ è€¹¥¹™¥¹¥Ñä¤ô(€€€€€€€€€€€€€€€€€€€€€€€€¹‰ÕÑÑ½¹MÑå±”¡•¹Ñ	ÕÑÑ½¹MÑå±” ¤¤¹™É…µ”¡µ¥¹!•¥¡Ğè€ĞĞ¤(€€€€€€€€€€€€€€€ô(€€€€€€€€€€€€€€€€¹™É…µ”¡µ…á]¥‘Ñ è€¹¥¹™¥¹¥Ñä°…±¥¹µ•¹Ğè€¹±•…‘¥¹œ¤(€€€€€€€€€€€€€€€€¹Á…‘‘¥¹œ ÄØ¤(€€€€€€€€€€€ô(€€€€€€€ô(€€€€€€€€¹¹…Ù¥…Ñ¥½¹Q¥Ñ±” ‹–öKš†–ş¯œˆ¤(€€€€€€€€¹¹…Ù¥…Ñ¥½¹	…ÉQ¥Ñ±•¥ÍÁ±…å5½‘” ¹¥¹±¥¹”¤(€€€€€€€€¹Ñ½½±‰…É	…­É½Õ¹¡ÁÁQ¡•µ”¹‰…­É½Õ¹°™½Èè€¹¹…Ù¥…Ñ¥½¹	…È¤(€€€ô)ô()ÍÑÉÕĞI•Á½ÉÑ•¹Ñ•ÉY¥•ÜèY¥•Üì(€€€¹Ù¥É½¹µ•¹Ñ=‰©•ĞÁÉ¥Ù…Ñ”Ù…ÈÍÑ½É”è9•İÍMÑ½É”(€€€¹Ù¥É½¹µ•¹Ñ=‰©•ĞÁÉ¥Ù…Ñ”Ù…È¡½Ñ9•İÍMÑ½É”è!½Ñ9•İÍMÑ½É”(€€€¹Ù¥É½¹µ•¹Ñ=‰©•ĞÁÉ¥Ù…Ñ”Ù…ÈÍ•ÑÑ¥¹ÍMÑ½É”èM•ÑÑ¥¹ÍMÑ½É”(€€€¹Ù¥É½¹µ•¹Ñ=‰©•ĞÁÉ¥Ù…Ñ”Ù…ÈÉ•Á½ÉÑMÑ½É”èI•Á½ÉÑMÑ½É”(€€€MÑ…Ñ”ÁÉ¥Ù…Ñ”Ù…ÈÍ¡½İ¥¹I•Á½ÉÑ•¹•É…Ñ½È€ô™…±Í”((€€€Ù…È‰½‘äèÍ½µ”Y¥•Üì(€€€€€€€9…Ù¥…Ñ¥½¹MÑ…¬ì(€€€€€€€€€€€iMÑ…¬ì(€€€€€€€€€€€€€€€%¹Ñ•±±¥•¹•MÉ••¹	…­É½Õ¹ ¤(€€€€€€€€€€€€€€€1¥¹•…ÉÉ…‘¥•¹Ğ¡½±½ÉÌèmÁÁQ¡•µ”¹‰É…¹‘%¹‘¥¼¹½Á…¥Ñä À¸ÄÈ¤°€¹±•…Ét°ÍÑ…ÉÑA½¥¹Ğè€¹Ñ½Á1•…‘¥¹œ°•¹‘A½¥¹Ğè€¹•¹Ñ•È¤(€€€€€€€€€€€€€€€€€€€€¹¥¹½É•ÍM…™•É•„ ¤(€€€€€€€€€€€€€€€MÉ½±±Y¥•Üì(€€€€€€€€€€€€€€€€€€€1…éåYMÑ…¬¡…±¥¹µ•¹Ğè€¹±•…‘¥¹œ°ÍÁ…¥¹œè€ÄØ¤ì(€€€€€€€€€€€€€€€€€€€€€€€É•Á½ÉÑ%¹ÑÉ¼(€€€€€€€€€€€€€€€€€€€€€€€É•Á½ÉÑMÑ…ÑÕÍMÑÉ¥À(€€€€€€€€€€€€€€€€€€€€€€€É•Á½ÉÑQ½½±‰…È(€€€€€€€€€€€€€€€€€€€€€€€¥˜É•Á½ÉÑMÑ½É”¹¥Í1½…‘¥¹œì(€€€€€€€€€€€€€€€€€€€€€€€€€€€•…ÑÕÉ•1½…‘¥¹MÑ…Ñ”¡Ñ¥Ñ±”è€‹š¶–r£–*ƒ¢ö÷š*—–F(ˆ°µ•ÍÍ…”è€‹–B3š¶—šr³šrëš*—–F+Ò‹–òW’â;–ş¯œˆ¤(€€€€€€€€€€€€€€€€€€€€€€€ô•±Í”¥˜É•Á½ÉÑMÑ½É”¹™¥±Ñ•É•‘I•Á½ÉÑÌ¹¥ÍµÁÑäì(€€€€€€€€€€€€€€€€€€€€€€€€€€€•…ÑÕÉ•µÁÑåMÑ…Ñ”¡¥½¸è€‰‘½Œ¹Ñ•áĞ¹µ…¹¥™å¥¹±…ÍÌˆ°Ñ¥Ñ±”è€‹šjš^ƒš*—–F(ˆ°µ•ÍÍ…”è€‹Rš"C’â’î÷š*—–F+–B;¾ò3–º’òk–në–ºk’şw–¶c–öOš^ÛjšZÃ¦^ï–ş¯Ÿˆ°…Ñ¥½¹Q¥Ñ±”è€‹Rš"C²³’â’î÷š*—–F(ˆ¤ì(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€Í¡½İ¥¹I•Á½ÉÑ•¹•É…Ñ½È€ôÑÉÕ”(€€€€€€€€€€€€€€€€€€€€€€€€€€€ô(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€¹™É…µ”¡µ…á]¥‘Ñ è€¹¥¹™¥¹¥Ñä¤(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€¹Á…‘‘¥¹œ ¹Ñ½À°€ÌÈ¤(€€€€€€€€€€€€€€€€€€€€€€€ô•±Í”ì(€€€€€€€€€€€€€€€€€€€€€€€€€€€½É… ¡É•Á½ÉÑMÑ½É”¹™¥±Ñ•É•‘I•Á½ÉÑÌ¤ìÉ•Á½ÉĞ¥¸(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€9…Ù¥…Ñ¥½¹1¥¹¬ì(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€I•Á½ÉÑ•Ñ…¥±Y¥•Ü¡É•Á½ÉÑ%èÉ•Á½ÉĞ¹¥¤(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€ô±…‰•°èì(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€I•Á½ÉÑMÕµµ…Éå…É¡É•Á½ÉĞèÉ•Á½ÉĞ¤(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€ô(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€¹‰ÕÑÑ½¹MÑå±” ¹Á±…¥¸¤(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€¹½¹Ñ•áÑ5•¹Ôì(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€	ÕÑÑ½¸ì(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€Q…Í¬ì…İ…¥ĞÉ•Á½ÉÑMÑ½É”¹Ñ½±•…Ù½É¥Ñ”¡¥èÉ•Á½ÉĞ¹¥¤ô(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€ô±…‰•°èì(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€1…‰•°¡É•Á½ÉĞ¹¥Í…Ù½É¥Ñ”€ü€‹–>[šÚ#šRÛ¢^<ˆ€è€‹šRÛ¢^<ˆ°ÍåÍÑ•µ%µ…”èÉ•Á½ÉĞ¹¥Í…Ù½É¥Ñ”€ü€‰ÍÑ…È¹Í±…Í ˆ€è€‰ÍÑ…Èˆ¤(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€ô(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€	ÕÑÑ½¸¡É½±”è€¹‘•ÍÑÉÕÑ¥Ù”¤ì(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€Q…Í¬ì…İ…¥ĞÉ•Á½ÉÑMÑ½É”¹‘•±•Ñ”¡¥èÉ•Á½ÉĞ¹¥¤ô(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€ô±…‰•°èì(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€1…‰•° ‹–"ƒ¦f“š*—–F(ˆ°ÍåÍÑ•µ%µ…”è€‰ÑÉ…Í ˆ¤(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€ô(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€ô(€€€€€€€€€€€€€€€€€€€€€€€€€€€ô(€€€€€€€€€€€€€€€€€€€€€€€ô(€€€€€€€€€€€€€€€€€€€ô(€€€€€€€€€€€€€€€€€€€€¹Á…‘‘¥¹œ ¹¡½É¥é½¹Ñ…°°€ÄØ¤(€€€€€€€€€€€€€€€€€€€€¹Á…‘‘¥¹œ ¹Ñ½À°€ÄÈ¤(€€€€€€€€€€€€€€€€€€€€¹Á…‘‘¥¹œ ¹‰½ÑÑ½´°€Èà¤(€€€€€€€€€€€€€€€ô(€€€€€€€€€€€ô(€€€€€€€€€€€€¹¹…Ù¥…Ñ¥½¹Q¥Ñ±” ‹š*—–F(ˆ¤(€€€€€€€€€€€€¹¹…Ù¥…Ñ¥½¹	…ÉQ¥Ñ±•¥ÍÁ±…å5½‘” ¹¥¹±¥¹”¤(€€€€€€€€€€€€¹Ñ½½±‰…É	…­É½Õ¹¡ÁÁQ¡•µ”¹‰…­É½Õ¹°™½Èè€¹¹…Ù¥…Ñ¥½¹	…È¤(€€€€€€€€€€€€¹Ñ½½±‰…Èì(€€€€€€€€€€€€€€€Q½½±‰…É%Ñ•´¡Á±…•µ•¹Ğè€¹Ñ½Á	…ÉQÉ…¥±¥¹œ¤ì(€€€€€€€€€€€€€€€€€€€	ÕÑÑ½¸ìÍ¡½İ¥¹I•Á½ÉÑ•¹•É…Ñ½È€ôÑÉÕ”ô±…‰•°èì(€€€€€€€€€€€€€€€€€€€€€€€Q½½±‰…É%½¹1…‰•°¡ÍåÍÑ•µ9…µ”è€‰Á±ÕÌˆ°±…‰•°è€‹Rš"Cš*—–F(ˆ¤(€€€€€€€€€€€€€€€€€€€ô(€€€€€€€€€€€€€€€ô(€€€€€€€€€€€ô(€€€€€€€€€€€€¹Í¡••Ğ¡¥ÍAÉ•Í•¹Ñ•è€‘Í¡½İ¥¹I•Á½ÉÑ•¹•É…Ñ½È¤ì(€€€€€€€€€€€€€€€I•Á½ÉÑ•¹•É…Ñ½ÉM¡••ĞìÑåÁ”°İ¥¹‘½İMÑ…ÉĞ°¥¹±Õ‘•IML°¥¹±Õ‘•!½Ñ±¥ÍĞ°±•¹Ñ °‘•ÁÑ °±…¹Õ…”¥¸(€€€€€€€€€€€€€€€€€€€Q…Í¬ì(€€€€€€€€€€€€€€€€€€€€€€€…İ…¥ĞÍÑ½É”¹É•™É•Í ¡Í¡½İÉÉ½Èè™…±Í”°…ÕÑ½I•Á½ÉĞè™…±Í”¤(€€€€€€€€€€€€€€€€€€€€€€€…İ…¥Ğ¡½Ñ9•İÍMÑ½É”¹É•™É•Í ¡Í•ÑÑ¥¹ÌèÍ•ÑÑ¥¹ÍMÑ½É”¹Í•ÑÑ¥¹Ì°Í¡½İÉÉ½Èè™…±Í”¤(€€€€€€€€€€€€€€€€€€€€€€€Ù…ÈÉ•Á½ÉÑM•ÑÑ¥¹Ì€ôÍ•ÑÑ¥¹ÍMÑ½É”¹Í•ÑÑ¥¹Ì(€€€€€€€€€€€€€€€€€€€€€€€É•Á½ÉÑM•ÑÑ¥¹Ì¹…¥¹…±åÍ¥Ì¹±…¹Õ…”€ô±…¹Õ…”(€€€€€€€€€€€€€€€€€€€€€€€É•Á½ÉÑM•ÑÑ¥¹Ì¹…¥¹…±åÍ¥Ì¹µ…á9•İÍ½É¹…±åÍ¥Ì€ôlØÀ°€ÄÔÀ°€ÌÀÁum‘•ÁÑ¡t(€€€€€€€€€€€€€€€€€€€€€€€É•Á½ÉÑM•ÑÑ¥¹Ì¹É•Á½ÉĞ¹µ…á9•İÍA•É-•åİ½É€ôlÔ°€À°€ÌÁum±•¹Ñ¡t(€€€€€€€€€€€€€€€€€€€€€€€±•ĞÉÍÍ%Ñ•µÌ€ô¥¹±Õ‘•IML€üÍÑ½É”¹¥Ñ•µÌ¹™¥±Ñ•Èì¥Ñ•´¥¸(€€€€€€€€€€€€€€€€€€€€€€€€€€€İ¥¹‘½İMÑ…ÉĞ¹µ…Àì€¡¥Ñ•´¹ÁÕ‰±¥Í¡•‘Ğ€üü€¹‘¥ÍÑ…¹ÑA…ÍĞ¤€øô€Àô€üüÑÉÕ”(€€€€€€€€€€€€€€€€€€€€€€€ô€èmt(€€€€€€€€€€€€€€€€€€€€€€€±•Ğ¡½Ñ%Ñ•µÌ€ô¥¹±Õ‘•!½Ñ±¥ÍĞ€ü¡½Ñ9•İÍMÑ½É”¹¥Ñ•µÌ¹™¥±Ñ•Èì¥Ñ•´¥¸(€€€€€€€€€€€€€€€€€€€€€€€€€€€İ¥¹‘½İMÑ…ÉĞ¹µ…Àì€¡¥Ñ•´¹ÁÕ‰±¥Í¡•‘Ğ€üü€¹‘¥ÍÑ…¹ÑA…ÍĞ¤€øô€Àô€üüÑÉÕ”(€€€€€€€€€€€€€€€€€€€€€€€ô€èmt(€€€€€€€€€€€€€€€€€€€€€€€…İ…¥ĞÉ•Á½ÉÑMÑ½É”¹•¹•É…Ñ”¡ÑåÁ”èÑåÁ”°Í•ÑÑ¥¹ÌèÉ•Á½ÉÑM•ÑÑ¥¹Ì°¥Ñ•µÌèÉÍÍ%Ñ•µÌ°¡½Ñ±¥ÍÑ%Ñ•µÌè¡½Ñ%Ñ•µÌ°İ¥¹‘½İMÑ…ÉĞèİ¥¹‘½İMÑ…ÉĞ°‘¥…¹½ÍÑ¥ÌèÉ•Á½ÉÑMÑ½É”¹‘¥…¹½ÍÑ¥Ì¡¹•İÌèÍÑ½É”°¡½Ñ9•İÌè¡½Ñ9•İÍMÑ½É”¤¤(€€€€€€€€€€€€€€€€€€€ô(€€€€€€€€€€€€€€€ô(€€€€€€€€€€€ô(€€€€€€€€€€€€¹½Ù•É±…äì(€€€€€€€€€€€€€€€¥˜É•Á½ÉÑMÑ½É”¹¥Í•¹•É…Ñ¥¹œì(€€€€€€€€€€€€€€€€€€€iMÑ…¬ì(€€€€€€€€€€€€€€€€€€€€€€€½±½È¹‰±…¬¹½Á…¥Ñä À¸Èà¤¹¥¹½É•ÍM…™•É•„ ¤(€€€€€€€€€€€€€€€€€€€€€€€•…ÑÕÉ•1½…‘¥¹MÑ…Ñ”¡Ñ¥Ñ±”è€‹š¶–r£Rš"Cš*—–F(ˆ°µ•ÍÍ…”è€‹¦¦n¶o¦'–"šzC–æÛ’şw–¶cšr³šrë–ş¯œˆ¤(€€€€€€€€€€€€€€€€€€€€€€€€€€€€¹™É…µ”¡µ…á]¥‘Ñ è€ÌÈÀ¤(€€€€€€€€€€€€€€€€€€€€€€€€€€€€¹Á…‘‘¥¹œ ÈĞ¤(€€€€€€€€€€€€€€€€€€€ô(€€€€€€€€€€€€€€€€€€€€¹ÑÉ…¹Í¥Ñ¥½¸ ¹½Á…¥Ñä¤(€€€€€€€€€€€€€€€ô(€€€€€€€€€€€ô(€€€€€€€€€€€€¹…¹¥µ…Ñ¥½¸¡ÁÁ¹¥µ…Ñ¥½¸¹ÍÑ…¹‘…É°Ù…±Õ”èÉ•Á½ÉÑMÑ½É”¹¥Í•¹•É…Ñ¥¹œ¤(€€€€€€€€€€€€¹Í•¹Í½Éå••‘‰…¬ ¹ÍÕ•ÍÌ°ÑÉ¥•ÈèÉ•Á½ÉÑMÑ½É”¹É•Á½ÉÑÌ¹½Õ¹Ğ¤(€€€€€€€€€€€€¹…±•ÉĞ ‹š*—–F+šN7’öpˆ°¥ÍAÉ•Í•¹Ñ•è	¥¹‘¥¹œ¡•ĞèìÉ•Á½ÉÑMÑ½É”¹•ÉÉ½É5•ÍÍ…”€„ô¹¥°ô°Í•Ğèì¥˜€„ÀìÉ•Á½ÉÑMÑ½É”¹•ÉÉ½É5•ÍÍ…”€ô¹¥°ôô¤¤ì(€€€€€€€€€€€€€€€	ÕÑÑ½¸ ‹¦7šZÃ–*ƒ¢öôˆ¤ìQ…Í¬ì…İ…¥ĞÉ•Á½ÉÑMÑ½É”¹±½… ¤ôô(€€€€€€€€€€€€€€€	ÕÑÑ½¸ ‹†»–ºhˆ°É½±”è€¹…¹•°¤ìÉ•Á½ÉÑMÑ½É”¹•ÉÉ½É5•ÍÍ…”€ô¹¥°ô(€€€€€€€€€€€ôµ•ÍÍ…”èì(€€€€€€€€€€€€€€€Q•áĞ¡É•Á½ÉÑMÑ½É”¹•ÉÉ½É5•ÍÍ…”€üü€ˆˆ¤(€€€€€€€€€€€ô(€€€€€€€€€€€€¹Ñ…Í¬ì…İ…¥ĞÉ•Á½ÉÑMÑ½É”¹±½… ¤ô(€€€€€€€ô(€€€ô((€€€ÁÉ¥Ù…Ñ”Ù…ÈÉ•Á½ÉÑMÑ…ÑÕÍMÑÉ¥ÀèÍ½µ”Y¥•Üì(€€€€€€€Y¥•İQ¡…Ñ¥ÑÌ¡¥¸è€¹¡½É¥é½¹Ñ…°¤ì(€€€€€€€€€€€!MÑ…¬¡ÍÁ…¥¹œè€à¤ìÉ•Á½ÉÑ5•ÑÉ¥Ìô(€€€€€€€€€€€YMÑ…¬¡ÍÁ…¥¹œè€à¤ìÉ•Á½ÉÑ5•ÑÉ¥Ìô(€€€€€€€ô(€€€ô((€€€Y¥•İ	Õ¥±‘•È(€€€ÁÉ¥Ù…Ñ”Ù…ÈÉ•Á½ÉÑ5•ÑÉ¥ÌèÍ½µ”Y¥•Üì(€€€€€€€AÉ•µ¥Õµ5•ÑÉ¥…É¡Ù…±Õ”è€‰p¡É•Á½ÉÑMÑ½É”¹É•Á½ÉÑÌ¹½Õ¹Ğ¤ˆ°±…‰•°è€‹–£¦£š*—–F(ˆ°¥½¸è€‰‘½Œ¹Ñ•áĞˆ°Ñ¥¹ĞèÁÁQ¡•µ”¹‰É…¹‘å…¸¤(€€€€€€€AÉ•µ¥Õµ5•ÑÉ¥…É¡Ù…±Õ”è€‰p¡É•Á½ÉÑMÑ½É”¹É•Á½ÉÑÌ¹™¥±Ñ•È¡p¹¥Í…Ù½É¥Ñ”¤¹½Õ¹Ğ¤ˆ°±…‰•°è€‹–ŞËšRÛ¢^<ˆ°¥½¸è€‰ÍÑ…È¹™¥±°ˆ°Ñ¥¹ĞèÁÁQ¡•µ”¹å•±±½Ü¤(€€€€€€€AÉ•µ¥Õµ5•ÑÉ¥…É¡Ù…±Õ”è€‰p¡É•Á½ÉÑMÑ½É”¹É•Á½ÉÑÌ¹™¥±Ñ•Èì€À¹ÑåÁ”€ôô€¹‘…¥±äô¹½Õ¹Ğ¤ˆ°±…‰•°è€‹š^—š*”ˆ°¥½¸è€‰…±•¹‘…Èˆ°Ñ¥¹ĞèÁÁQ¡•µ”¹‰É…¹‘5…•¹Ñ„¤(€€€ô((€€€ÁÉ¥Ù…Ñ”Ù…ÈÉ•Á½ÉÑQ½½±‰…ÈèÍ½µ”Y¥•Üì(€€€€€€€YMÑ…¬¡…±¥¹µ•¹Ğè€¹±•…‘¥¹œ°ÍÁ…¥¹œè€ÄÀ¤ì(€€€€€€€€€€€!MÑ…¬¡ÍÁ…¥¹œè€à¤ì(€€€€€€€€€€€€€€€%µ…”¡ÍåÍÑ•µ9…µ”è€‰±¥¹”¸Ì¹¡½É¥é½¹Ñ…°¹‘•É•…Í”¹¥É±”¹™¥±°ˆ¤(€€€€€€€€€€€€€€€€€€€€¹™½É•É½Õ¹‘MÑå±”¡ÁÁQ¡•µ”¹‰É…¹‘å…¸¤(€€€€€€€€€€€€€€€Q•áĞ ‹š*—–F+šÒˆˆ¤(€€€€€€€€€€€€€€€€€€€€¹™½¹Ğ¡ÁÁQ¡•µ”¹¡•…‘±¥¹•½¹Ğ¤(€€€€€€€€€€€€€€€€€€€€¹™½É•É½Õ¹‘MÑå±”¡ÁÁQ¡•µ”¹Ñ•áÑAÉ¥µ…Éä¤(€€€€€€€€€€€€€€€MÁ…•È ¤(€€€€€€€€€€€€€€€Q•áĞ¡É•Á½ÉÑMÑ½É”¹™…Ù½É¥Ñ•Í=¹±ä€ü€‹’îšRÛ¢^<ˆ€èÉ•Á½ÉÑMÑ½É”¹Í•±•Ñ•‘QåÁ”ü¹‘¥ÍÁ±…å9…µ”€üü€‹–£¦£Æï–z,ˆ¤(€€€€€€€€€€€€€€€€€€€€¹™½¹Ğ¡ÁÁQ¡•µ”¹…ÁÑ¥½¹½¹Ğ¤(€€€€€€€€€€€€€€€€€€€€¹™½É•É½Õ¹‘MÑå±”¡ÁÁQ¡•µ”¹Ñ•áÑM•½¹‘…Éä¤(€€€€€€€€€€€ô(€€€€€€€€€€€!MÑ…¬¡ÍÁ…¥¹œè€à¤ì(€€€€€€€€€€€€€€€!MÑ…¬¡ÍÁ…¥¹œè€à¤ì(€€€€€€€€€€€€€€€€€€€%µ…”¡ÍåÍÑ•µ9…µ”è€‰µ…¹¥™å¥¹±…ÍÌˆ¤(€€€€€€€€€€€€€€€€€€€€€€€€¹™½É•É½Õ¹‘MÑå±”¡ÁÁQ¡•µ”¹‰É…¹‘å…¸¤(€€€€€€€€€€€€€€€€€€€Q•áÑ¥•± ‹šBsÒ‹š*—–F+š‚¦Š`ˆ°Ñ•áĞè€‘É•Á½ÉÑMÑ½É”¹Í•…É¡Q•áĞ¤(€€€€€€€€€€€€€€€€€€€€€€€€¹Ñ•áÑ¥•±‘MÑå±” ¹Á±…¥¸¤(€€€€€€€€€€€€€€€€€€€¥˜€…É•Á½ÉÑMÑ½É”¹Í•…É¡Q•áĞ¹¥ÍµÁÑäì(€€€€€€€€€€€€€€€€€€€€€€€	ÕÑÑ½¸ìÉ•Á½ÉÑMÑ½É”¹Í•…É¡Q•áĞ€ô€ˆˆô±…‰•°èì(€€€€€€€€€€€€€€€€€€€€€€€€€€€%µ…”¡ÍåÍÑ•µ9…µ”è€‰áµ…É¬¹¥É±”¹™¥±°ˆ¤(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€¹™½É•É½Õ¹‘MÑå±”¡ÁÁQ¡•µ”¹Ñ•áÑQ•ÉÑ¥…Éä¤(€€€€€€€€€€€€€€€€€€€€€€€ô(€€€€€€€€€€€€€€€€€€€ô(€€€€€€€€€€€€€€€ô(€€€€€€€€€€€€€€€€¹Á…‘‘¥¹œ ¹¡½É¥é½¹Ñ…°°€ÄÈ¤(€€€€€€€€€€€€€€€€¹Á…‘‘¥¹œ ¹Ù•ÉÑ¥…°°€ÄÄ¤(€€€€€€€€€€€€€€€€¹¥¹Ñ•±±¥•¹•…É¡Ñ¥¹ĞèÁÁQ¡•µ”¹‰É…¹‘å…¸°½É¹•ÉI…‘¥ÕÌè€ÄÈ¤(€€€€€€€€€€€€€€€5•¹Ôì(€€€€€€€€€€€€€€€€€€€	ÕÑÑ½¸ ‹–£¦£Æï–z,ˆ¤ìÉ•Á½ÉÑMÑ½É”¹Í•±•Ñ•‘QåÁ”€ô¹¥°ô(€€€€€€€€€€€€€€€€€€€½É… ¡I•Á½ÉÑQåÁ”¹…±±…Í•Ì°¥èp¹Í•±˜¤ìÑåÁ”¥¸(€€€€€€€€€€€€€€€€€€€€€€€	ÕÑÑ½¸¡ÑåÁ”¹‘¥ÍÁ±…å9…µ”¤ìÉ•Á½ÉÑMÑ½É”¹Í•±•Ñ•‘QåÁ”€ôÑåÁ”ô(€€€€€€€€€€€€€€€€€€€ô(€€€€€€€€€€€€€€€€€€€¥Ù¥‘•È ¤(€€€€€€€€€€€€€€€€€€€Q½±” ‹’îšRÛ¢^<ˆ°¥Í=¸è€‘É•Á½ÉÑMÑ½É”¹™…Ù½É¥Ñ•Í=¹±ä¤(€€€€€€€€€€€€€€€ô±…‰•°èì(€€€€€€€€€€€€€€€€€€€%µ…”¡ÍåÍÑ•µ9…µ”èÉ•Á½ÉÑMÑ½É”¹Í•±•Ñ•‘QåÁ”€ôô¹¥°€˜˜€…É•Á½ÉÑMÑ½É”¹™…Ù½É¥Ñ•Í=¹±ä€ü€‰±¥¹”¸Ì¹¡½É¥é½¹Ñ…°¹‘•É•…Í”¹¥É±”ˆ€è€‰±¥¹”¸Ì¹¡½É¥é½¹Ñ…°¹‘•É•…Í”¹¥É±”¹™¥±°ˆ¤(€€€€€€€€€€€€€€€€€€€€€€€€¹™½¹Ğ ¹Ñ¥Ñ±”Ì¤(€€€€€€€€€€€€€€€€€€€€€€€€¹™½É•É½Õ¹‘MÑå±”¡ÁÁQ¡•µ”¹å…¸¤(€€€€€€€€€€€€€€€€€€€€€€€€¹™É…µ”¡İ¥‘Ñ è€ĞÈ°¡•¥¡Ğè€ĞÈ¤(€€€€€€€€€€€€€€€€€€€€€€€€¹¥¹Ñ•±±¥•¹•…É¡Ñ¥¹ĞèÁÁQ¡•µ”¹‰É…¹‘å…¸°½É¹•ÉI…‘¥ÕÌè€ÄÈ¤(€€€€€€€€€€€€€€€ô(€€€€€€€€€€€ô(€€€€€€€ô(€€€ô((€€€ÁÉ¥Ù…Ñ”Ù…ÈÉ•Á½ÉÑ%¹ÑÉ¼èÍ½µ”Y¥•Üì(€€€€€€€%¹Ñ•±±¥•¹•A…•!•…‘•È (€€€€€€€€€€€•å•‰É½Üè€‰IA=IPI!%Yˆ°(€€€€€€€€€€€Ñ¥Ñ±”è€‹šr³–rÃšš*—š†š† ˆ°(€€€€€€€€€€€ÍÕ‰Ñ¥Ñ±”è€‹’şw–¶c¦¦nš^Û–"ïjšZÃ¦^ï–ş¯Ÿ–J3–"šzCîOšzpˆ°(€€€€€€€€€€€¥½¸è€‰‘½Œ¹Ñ•áĞ¹µ…¹¥™å¥¹±…ÍÌˆ°(€€€€€€€€€€€…ÍÍ•Ñ9…µ”è€‰QÉ•¹‘I…‘…ÈµI•Á½ÉÑÍ!•É¼ˆ(€€€€€€€€¤(€€€ô)ô()ÍÑÉÕĞ½µÁ…Ñ••‘…ÉèY¥•Üì(€€€±•Ğ¥Ñ•´è9•İÍ%Ñ•´(€€€¹Ù¥É½¹µ•¹Ñ=‰©•ĞÁÉ¥Ù…Ñ”Ù…ÈÍÑ½É”è9•İÍMÑ½É”((€€€Ù…È‰½‘äèÍ½µ”Y¥•Üì(€€€€€€€!MÑ…¬¡…±¥¹µ•¹Ğè€¹Ñ½À°ÍÁ…¥¹œè€ÄÈ¤ì(€€€€€€€€€€€¥É±” ¤(€€€€€€€€€€€€€€€€¹™¥±°¡¥Ñ•´¹¥ÍI•…€üÁÁQ¡•µ”¹Ñ•áÑQ•ÉÑ¥…Éä€èÁÁQ¡•µ”¹å…¸¤(€€€€€€€€€€€€€€€€¹™É…µ”¡İ¥‘Ñ è€à°¡•¥¡Ğè€à¤(€€€€€€€€€€€€€€€€¹Á…‘‘¥¹œ ¹Ñ½À°€Ø¤(€€€€€€€€€€€YMÑ…¬¡…±¥¹µ•¹Ğè€¹±•…‘¥¹œ°ÍÁ…¥¹œè€Ô¤ì(€€€€€€€€€€€€€€€!MÑ…¬ì(€€€€€€€€€€€€€€€€€€€Q•áĞ¡¥Ñ•´¹Í½ÕÉ”¹ÕÁÁ•É…Í• ¤¤(€€€€€€€€€€€€€€€€€€€€€€€€¹™½¹Ğ¡ÁÁQ¡•µ”¹…ÁÑ¥½¹½¹Ğ¤(€€€€€€€€€€€€€€€€€€€€€€€€¹ÑÉ…­¥¹œ À¸à¤(€€€€€€€€€€€€€€€€€€€€€€€€¹™½É•É½Õ¹‘MÑå±”¡ÁÁQ¡•µ”¹å…¸¤(€€€€€€€€€€€€€€€€€€€MÁ…•È ¤(€€€€€€€€€€€€€€€€€€€¥˜¥Ñ•´¹¥Í…Ù½É¥Ñ”ì%µ…”¡ÍåÍÑ•µ9…µ”è€‰ÍÑ…È¹™¥±°ˆ¤¹™½É•É½Õ¹‘MÑå±”¡ÁÁQ¡•µ”¹å•±±½Ü¤ô(€€€€€€€€€€€€€€€ô(€€€€€€€€€€€€€€€Q•áĞ¡¥Ñ•´¹ÑÉ…¹Í±…Ñ•‘Q¥Ñ±”€üü¥Ñ•´¹Ñ¥Ñ±”¤(€€€€€€€€€€€€€€€€€€€€¹™½¹Ğ¡ÁÁQ¡•µ”¹¡•…‘±¥¹•½¹Ğ¤(€€€€€€€€€€€€€€€€€€€€¹™½É•É½Õ¹‘MÑå±”¡ÁÁQ¡•µ”¹Ñ•áÑAÉ¥µ…Éä¤(€€€€€€€€€€€€€€€€€€€€¹µÕ±Ñ¥±¥¹•Q•áÑ±¥¹µ•¹Ğ ¹±•…‘¥¹œ¤(€€€€€€€€€€€€€€€€€€€€¹±¥¹•1¥µ¥Ğ È¤(€€€€€€€€€€€€€€€¥˜¥Ñ•´¹ÑÉ…¹Í±…Ñ•‘Q¥Ñ±”€„ô¹¥°ì(€€€€€€€€€€€€€€€€€€€1…‰•° ‹–ŞËşï¢¾Dˆ°ÍåÍÑ•µ%µ…”è€‰¡…É…Ñ•È¹‰½½¬¹±½Í•ˆ¤(€€€€€€€€€€€€€€€€€€€€€€€€¹™½¹Ğ¡ÁÁQ¡•µ”¹…ÁÑ¥½¹½¹Ğ¤(€€€€€€€€€€€€€€€€€€€€€€€€¹™½É•É½Õ¹‘MÑå±”¡ÁÁQ¡•µ”¹‰É…¹‘%¹‘¥¼¤(€€€€€€€€€€€€€€€ô(€€€€€€€€€€€€€€€!MÑ…¬¡ÍÁ…¥¹œè€Ø¤ì(€€€€€€€€€€€€€€€€€€€Q•áĞ¡¥Ñ•´¹ÁÕ‰±¥Í¡•‘Ğü¹É•±…Ñ¥Ù••ÍÉ¥ÁÑ¥½¸€üü€‹–"k–"hˆ¤(€€€€€€€€€€€€€€€€€€€Q•áĞ ‹
Üˆ¤(€€€€€€€€€€€€€€€€€€€Q•áĞ¡¥Ñ•´¹¥ÍI•…€ü€‹–ŞË¢¾ìˆ€è€‹šr«¢¾ìˆ¤(€€€€€€€€€€€€€€€€€€€¥˜¥Ñ•´¹ÍÕµµ…Éä€„ô¹¥°ì(€€€€€€€€€€€€€€€€€€€€€€€Q•áĞ ‹
Üˆ¤(€€€€€€€€€€€€€€€€€€€€€€€1…‰•° ‹–ŞËšFc¢šˆ°ÍåÍÑ•µ%µ…”è€‰ÍÁ…É­±•Ìˆ¤(€€€€€€€€€€€€€€€€€€€ô(€€€€€€€€€€€€€€€ô(€€€€€€€€€€€€€€€€¹™½¹Ğ¡ÁÁQ¡•µ”¹…ÁÑ¥½¹½¹Ğ¤(€€€€€€€€€€€€€€€€¹™½É•É½Õ¹‘MÑå±”¡ÁÁQ¡•µ”¹Ñ•áÑQ•ÉÑ¥…Éä¤(€€€€€€€€€€€ô(€€€€€€€ô(€€€€€€€€¹Á…‘‘¥¹œ ÄÈ¤(€€€€€€€€¹¥¹Ñ•±±¥•¹•…É¡Ñ¥¹Ğè¥Ñ•´¹¥ÍI•…€üÁÁQ¡•µ”¹Ñ•áÑQ•ÉÑ¥…Éä€èÁÁQ¡•µ”¹å…¸°½É¹•ÉI…‘¥ÕÌè€ÄØ¤(€€€€€€€€¹½¹Ñ•áÑ5•¹Ôì(€€€€€€€€€€€	ÕÑÑ½¸ì(€€€€€€€€€€€€€€€Q…Í¬ì…İ…¥ĞÍÑ½É”¹Ñ½±•…Ù½É¥Ñ”¡¥Ñ•´¤ô(€€€€€€€€€€€ô±…‰•°èì(€€€€€€€€€€€€€€€1…‰•°¡¥Ñ•´¹¥Í…Ù½É¥Ñ”€ü€‹–>[šÚ#šRÛ¢^<ˆ€è€‹šRÛ¢^<ˆ°ÍåÍÑ•µ%µ…”è¥Ñ•´¹¥Í…Ù½É¥Ñ”€ü€‰ÍÑ…È¹Í±…Í ˆ€è€‰ÍÑ…Èˆ¤(€€€€€€€€€€€ô(€€€€€€€€€€€¥˜€…¥Ñ•´¹¥ÍI•…ì(€€€€€€€€€€€€€€€	ÕÑÑ½¸ì(€€€€€€€€€€€€€€€€€€€Q…Í¬ì…İ…¥ĞÍÑ½É”¹µ…É­I•…¡¥Ñ•´¤ô(€€€€€€€€€€€€€€€ô±…‰•°èì(€€€€€€€€€€€€€€€€€€€1…‰•° ‹š‚¢ºÃ–ŞË¢¾ìˆ°ÍåÍÑ•µ%µ…”è€‰¡•­µ…É¬¹¥É±”ˆ¤(€€€€€€€€€€€€€€€ô(€€€€€€€€€€€ô(€€€€€€€ô(€€€ô)ô()ÍÑÉÕĞ••‘¥±Ñ•É¡¥ÀèY¥•Üì(€€€±•ĞÑ¥Ñ±”èMÑÉ¥¹œ(€€€±•Ğ¥ÍM•±•Ñ•è	½½°(€€€±•Ğ…Ñ¥½¸è€ ¤€´øY½¥((€€€Ù…È‰½‘äèÍ½µ”Y¥•Üì(€€€€€€€	ÕÑÑ½¸¡…Ñ¥½¸è…Ñ¥½¸¤ì(€€€€€€€€€€€%¹Ñ•±±¥•¹•¥±Ñ•É¡¥À¡Ñ¥Ñ±”°¥ÍM•±•Ñ•è¥ÍM•±•Ñ•¤(€€€€€€€ô(€€€€€€€€¹‰ÕÑÑ½¹MÑå±” ¹Á±…¥¸¤(€€€ô)ô()ÍÑÉÕĞ%¹Í¥¡ÑA…¹•°ñ½¹Ñ•¹ĞèY¥•ÜøèY¥•Üì(€€€±•ĞÑ¥Ñ±”èMÑÉ¥¹œ(€€€±•Ğ¥½¸èMÑÉ¥¹œ(€€€±•ĞÑ¥¹Ğè½±½È(€€€±•Ğ½¹Ñ•¹Ğè½¹Ñ•¹Ğ((€€€¥¹¥Ğ¡Ñ¥Ñ±”èMÑÉ¥¹œ°¥½¸èMÑÉ¥¹œ°Ñ¥¹Ğè½±½È°Y¥•İ	Õ¥±‘•È½¹Ñ•¹Ğè€ ¤€´ø½¹Ñ•¹Ğ¤ì(€€€€€€€Í•±˜¹Ñ¥Ñ±”€ôÑ¥Ñ±”(€€€€€€€Í•±˜¹¥½¸€ô¥½¸(€€€€€€€Í•±˜¹Ñ¥¹Ğ€ôÑ¥¹Ğ(€€€€€€€Í•±˜¹½¹Ñ•¹Ğ€ô½¹Ñ•¹Ğ ¤(€€€ô((€€€Ù…È‰½‘äèÍ½µ”Y¥•Üì(€€€€€€€YMÑ…¬¡…±¥¹µ•¹Ğè€¹±•…‘¥¹œ°ÍÁ…¥¹œè€ÄÀ¤ì(€€€€€€€€€€€1…‰•°¡Ñ¥Ñ±”°ÍåÍÑ•µ%µ…”è¥½¸¤(€€€€€€€€€€€€€€€€¹™½¹Ğ¡ÁÁQ¡•µ”¹¡•…‘±¥¹•½¹Ğ¤(€€€€€€€€€€€€€€€€¹™½É•É½Õ¹‘MÑå±”¡Ñ¥¹Ğ¤(€€€€€€€€€€€½¹Ñ•¹Ğ(€€€€€€€ô(€€€€€€€€¹Á…‘‘¥¹œ ÄÌ¤(€€€€€€€€¹™É…µ”¡µ…á]¥‘Ñ è€¹¥¹™¥¹¥Ñä°…±¥¹µ•¹Ğè€¹±•…‘¥¹œ¤(€€€€€€€€¹¥¹Ñ•±±¥•¹•…É¡Ñ¥¹ĞèÑ¥¹Ğ°½É¹•ÉI…‘¥ÕÌè€Äà¤(€€€ô)ô()ÍÑÉÕĞ%¹Í¥¡Ñ5•ÑÉ¥ŒèY¥•Üì(€€€±•ĞÙ…±Õ”èMÑÉ¥¹œ(€€€±•Ğ±…‰•°èMÑÉ¥¹œ(€€€±•ĞÑ¥¹Ğè½±½È((€€€Ù…È‰½‘äèÍ½µ”Y¥•Üì(€€€€€€€YMÑ…¬¡…±¥¹µ•¹Ğè€¹±•…‘¥¹œ°ÍÁ…¥¹œè€Ğ¤ì(€€€€€€€€€€€Q•áĞ¡Ù…±Õ”¤¹™½¹Ğ¡ÁÁQ¡•µ”¹É…¹­½¹Ğ¤¹™½É•É½Õ¹‘MÑå±”¡Ñ¥¹Ğ¤(€€€€€€€€€€€Q•áĞ¡±…‰•°¤¹™½¹Ğ¡ÁÁQ¡•µ”¹…ÁÑ¥½¹½¹Ğ¤¹™½É•É½Õ¹‘MÑå±”¡ÁÁQ¡•µ”¹Ñ•áÑQ•ÉÑ¥…Éä¤(€€€€€€€ô(€€€€€€€€¹™É…µ”¡µ…á]¥‘Ñ è€¹¥¹™¥¹¥Ñä°…±¥¹µ•¹Ğè€¹±•…‘¥¹œ¤(€€€ô)ô()ÁÉ¥Ù…Ñ”ÍÑÉÕĞ••‘MÕµµ…Éå5•ÑÉ¥ŒèY¥•Üì(€€€±•ĞÙ…±Õ”èMÑÉ¥¹œ(€€€±•Ğ±…‰•°èMÑÉ¥¹œ(€€€±•ĞÑ¥¹Ğè½±½È((€€€Ù…È‰½‘äèÍ½µ”Y¥•Üì(€€€€€€€YMÑ…¬¡…±¥¹µ•¹Ğè€¹±•…‘¥¹œ°ÍÁ…¥¹œè€Ì¤ì(€€€€€€€€€€€Q•áĞ¡Ù…±Õ”¤(€€€€€€€€€€€€€€€€¹™½¹Ğ¡ÁÁQ¡•µ”¹É…¹­½¹Ğ¤(€€€€€€€€€€€€€€€€¹™½É•É½Õ¹‘MÑå±”¡Ñ¥¹Ğ¤(€€€€€€€€€€€Q•áĞ¡±…‰•°¤(€€€€€€€€€€€€€€€€¹™½¹Ğ¡ÁÁQ¡•µ”¹…ÁÑ¥½¹½¹Ğ¤(€€€€€€€€€€€€€€€€¹™½É•É½Õ¹‘MÑå±”¡ÁÁQ¡•µ”¹Ñ•áÑQ•ÉÑ¥…Éä¤(€€€€€€€€€€€€€€€€¹±¥¹•1¥µ¥Ğ Ä¤(€€€€€€€ô(€€€€€€€€¹™É…µ”¡µ…á]¥‘Ñ è€¹¥¹™¥¹¥Ñä°…±¥¹µ•¹Ğè€¹±•…‘¥¹œ¤(€€€ô)ô()ÁÉ¥Ù…Ñ”ÍÑÉÕĞ±½İ1…å½ÕĞèY¥•Üì(€€€±•Ğ¥Ñ•µÌèmMÑÉ¥¹t((€€€Ù…È‰½‘äèÍ½µ”Y¥•Üì(€€€€€€€MÉ½±±Y¥•Ü ¹¡½É¥é½¹Ñ…°°Í¡½İÍ%¹‘¥…Ñ½ÉÌè™…±Í”¤ì(€€€€€€€€€€€!MÑ…¬¡ÍÁ…¥¹œè€à¤ì(€€€€€€€€€€€€€€€½É… ¡¥Ñ•µÌ°¥èp¹Í•±˜¤ì¥Ñ•´¥¸(€€€€€€€€€€€€€€€€€€€Q•áĞ¡¥Ñ•´¤(€€€€€€€€€€€€€€€€€€€€€€€€¹™½¹Ğ¡ÁÁQ¡•µ”¹…ÁÑ¥½¹½¹Ğ¤(€€€€€€€€€€€€€€€€€€€€€€€€¹™½É•É½Õ¹‘MÑå±”¡ÁÁQ¡•µ”¹‰…­É½Õ¹¤(€€€€€€€€€€€€€€€€€€€€€€€€¹Á…‘‘¥¹œ ¹¡½É¥é½¹Ñ…°°€ÄÄ¤(€€€€€€€€€€€€€€€€€€€€€€€€¹Á…‘‘¥¹œ ¹Ù•ÉÑ¥…°°€Ü¤(€€€€€€€€€€€€€€€€€€€€€€€€¹‰…­É½Õ¹¡ÁÁQ¡•µ”¹å•±±½Ü¤(€€€€€€€€€€€€€€€€€€€€€€€€¹±¥ÁM¡…Á”¡…ÁÍÕ±” ¤¤(€€€€€€€€€€€€€€€ô(€€€€€€€€€€€ô(€€€€€€€ô(€€€ô)ô()ÍÑÉÕĞM½ÕÉ•!•…±Ñ¡	…¹¹•ÈèY¥•Üì(€€€±•ĞÑ¥Ñ±”èMÑÉ¥¹œ(€€€±•Ğ‘•Ñ…¥°èMÑÉ¥¹œ(€€€±•ĞÑ¥¹Ğè½±½È((€€€Ù…È‰½‘äèÍ½µ”Y¥•Üì(€€€€€€€!MÑ…¬¡…±¥¹µ•¹Ğè€¹Ñ½À°ÍÁ…¥¹œè€ÄÀ¤ì(€€€€€€€€€€€%µ…”¡ÍåÍÑ•µ9…µ”è€‰•á±…µ…Ñ¥½¹µ…É¬¹ÑÉ¥…¹±”¹™¥±°ˆ¤(€€€€€€€€€€€€€€€€¹™½É•É½Õ¹‘MÑå±”¡Ñ¥¹Ğ¤(€€€€€€€€€€€YMÑ…¬¡…±¥¹µ•¹Ğè€¹±•…‘¥¹œ°ÍÁ…¥¹œè€Ì¤ì(€€€€€€€€€€€€€€€Q•áĞ¡Ñ¥Ñ±”¤¹™½¹Ğ¡ÁÁQ¡•µ”¹¡•…‘±¥¹•½¹Ğ¤¹™½É•É½Õ¹‘MÑå±”¡ÁÁQ¡•µ”¹Ñ•áÑAÉ¥µ…Éä¤(€€€€€€€€€€€€€€€Q•áĞ¡‘•Ñ…¥°¤¹™½¹Ğ¡ÁÁQ¡•µ”¹…ÁÑ¥½¹½¹Ğ¤¹™½É•É½Õ¹‘MÑå±”¡ÁÁQ¡•µ”¹Ñ•áÑM•½¹‘…Éä¤¹±¥¹•1¥µ¥Ğ Ì¤(€€€€€€€€€€€ô(€€€€€€€€€€€MÁ…•È¡µ¥¹1•¹Ñ è€À¤(€€€€€€€ô(€€€€€€€€¹Á…‘‘¥¹œ ÄÈ¤(€€€€€€€€¹‰…­É½Õ¹¡Ñ¥¹Ğ¹½Á…¥Ñä À¸Àä¤¤(€€€€€€€€¹½Ù•É±…ä¡I½Õ¹‘•‘I•Ñ…¹±”¡½É¹•ÉI…‘¥ÕÌè€ÄĞ°ÍÑå±”è€¹½¹Ñ¥¹Õ½ÕÌ¤¹ÍÑÉ½­”¡Ñ¥¹Ğ¹½Á…¥Ñä À¸Èà¤°±¥¹•]¥‘Ñ è€Ä¤¤(€€€€€€€€¹±¥ÁM¡…Á”¡I½Õ¹‘•‘I•Ñ…¹±”¡½É¹•ÉI…‘¥ÕÌè€ÄĞ°ÍÑå±”è€¹½¹Ñ¥¹Õ½ÕÌ¤¤(€€€ô)ô()ÍÑÉÕĞ•…ÑÕÉ•µÁÑåMÑ…Ñ”èY¥•Üì(€€€¹Ù¥É½¹µ•¹Ğ¡p¹‘å¹…µ¥QåÁ•M¥é”¤ÁÉ¥Ù…Ñ”Ù…È‘å¹…µ¥QåÁ•M¥é”(€€€¹Ù¥É½¹µ•¹Ğ¡p¹…•ÍÍ¥‰¥±¥ÑåI•‘Õ•5½Ñ¥½¸¤ÁÉ¥Ù…Ñ”Ù…ÈÉ•‘Õ•5½Ñ¥½¸(€€€±•Ğ¥½¸èMÑÉ¥¹œ(€€€±•ĞÑ¥Ñ±”èMÑÉ¥¹œ(€€€±•Ğµ•ÍÍ…”èMÑÉ¥¹œ(€€€±•Ğ…Ñ¥½¹Q¥Ñ±”èMÑÉ¥¹œü(€€€±•Ğ…Ñ¥½¸è€  ¤€´øY½¥¤ü((€€€¥¹¥Ğ¡¥½¸èMÑÉ¥¹œ°Ñ¥Ñ±”èMÑÉ¥¹œ°µ•ÍÍ…”èMÑÉ¥¹œ°…Ñ¥½¹Q¥Ñ±”èMÑÉ¥¹œü€ô¹¥°°…Ñ¥½¸è€  ¤€´øY½¥¤ü€ô¹¥°¤ì(€€€€€€€Í•±˜¹¥½¸€ô¥½¸(€€€€€€€Í•±˜¹Ñ¥Ñ±”€ôÑ¥Ñ±”(€€€€€€€Í•±˜¹µ•ÍÍ…”€ôµ•ÍÍ…”(€€€€€€€Í•±˜¹…Ñ¥½¹Q¥Ñ±”€ô…Ñ¥½¹Q¥Ñ±”(€€€€€€€Í•±˜¹…Ñ¥½¸€ô…Ñ¥½¸(€€€ô((€€€Ù…È‰½‘äèÍ½µ”Y¥•Üì(€€€€€€€YMÑ…¬¡ÍÁ…¥¹œè€ÄÈ¤ì(€€€€€€€€€€€¥˜€…‘å¹…µ¥QåÁ•M¥é”¹¥Í•ÍÍ¥‰¥±¥ÑåM¥é”ì(€€€€€€€€€€€€€€€%µ…” ‰QÉ•¹‘I…‘…ÈµµÁÑåMÑ…Ñ”ˆ¤(€€€€€€€€€€€€€€€€€€€€¹É•Í¥é…‰±” ¤(€€€€€€€€€€€€€€€€€€€€¹Í…±•‘Q½¥Ğ ¤(€€€€€€€€€€€€€€€€€€€€¹™É…µ”¡µ…á]¥‘Ñ è€ÄĞÀ°µ…á!•¥¡Ğè€àØ¤(€€€€€€€€€€€€€€€€€€€€¹±¥ÁM¡…Á”¡I½Õ¹‘•‘I•Ñ…¹±”¡½É¹•ÉI…‘¥ÕÌè€ÄĞ°ÍÑå±”è€¹½¹Ñ¥¹Õ½ÕÌ¤¤(€€€€€€€€€€€€€€€€€€€€¹½Ù•É±…äì(€€€€€€€€€€€€€€€€€€€€€€€1¥¹•…ÉÉ…‘¥•¹Ğ¡½±½ÉÌèl¹±•…È°ÁÁQ¡•µ”¹‰…­É½Õ¹¹½Á…¥Ñä À¸ÈÈ¥t°ÍÑ…ÉÑA½¥¹Ğè€¹Ñ½À°•¹‘A½¥¹Ğè€¹‰½ÑÑ½´¤(€€€€€€€€€€€€€€€€€€€€€€€€€€€€¹±¥ÁM¡…Á”¡I½Õ¹‘•‘I•Ñ…¹±”¡½É¹•ÉI…‘¥ÕÌè€ÄĞ°ÍÑå±”è€¹½¹Ñ¥¹Õ½ÕÌ¤¤(€€€€€€€€€€€€€€€€€€€ô(€€€€€€€€€€€€€€€€€€€€¹…•ÍÍ¥‰¥±¥Ñå!¥‘‘•¸¡ÑÉÕ”¤(€€€€€€€€€€€ô(€€€€€€€€€€€%µ…”¡ÍåÍÑ•µ9…µ”è¥½¸¤(€€€€€€€€€€€€€€€€¹™½¹Ğ ¹ÍåÍÑ•´¡Í¥é”è€ÈÈ°İ•¥¡Ğè€¹±¥¡Ğ¤¤(€€€€€€€€€€€€€€€€¹™½É•É½Õ¹‘MÑå±”¡ÁÁQ¡•µ”¹‰É…¹‘å…¸¤(€€€€€€€€€€€Q•áĞ¡Ñ¥Ñ±”¤(€€€€€€€€€€€€€€€€¹™½¹Ğ¡ÁÁQ¡•µ”¹Í•Ñ¥½¹Q¥Ñ±•½¹Ğ¤(€€€€€€€€€€€€€€€€¹™½É•É½Õ¹‘MÑå±”¡ÁÁQ¡•µ”¹Ñ•áÑAÉ¥µ…Éä¤(€€€€€€€€€€€Q•áĞ¡µ•ÍÍ…”¤(€€€€€€€€€€€€€€€€¹™½¹Ğ¡ÁÁQ¡•µ”¹‰½‘å½¹Ğ¤(€€€€€€€€€€€€€€€€¹™½É•É½Õ¹‘MÑå±”¡ÁÁQ¡•µ”¹Ñ•áÑM•½¹‘…Éä¤(€€€€€€€€€€€€€€€€¹µÕ±Ñ¥±¥¹•Q•áÑ±¥¹µ•¹Ğ ¹•¹Ñ•È¤(€€€€€€€€€€€€€€€€¹™¥á•‘M¥é”¡¡½É¥é½¹Ñ…°è™…±Í”°Ù•ÉÑ¥…°èÑÉÕ”¤(€€€€€€€€€€€¥˜±•Ğ…Ñ¥½¹Q¥Ñ±”°±•Ğ…Ñ¥½¸ì(€€€€€€€€€€€€€€€	ÕÑÑ½¸¡…Ñ¥½¸è…Ñ¥½¸¤ì(€€€€€€€€€€€€€€€€€€€1…‰•°¡…Ñ¥½¹Q¥Ñ±”°ÍåÍÑ•µ%µ…”è€‰…ÉÉ½Ü¹±½­İ¥Í”ˆ¤(€€€€€€€€€€€€€€€€€€€€€€€€¹™É…µ”¡µ…á]¥‘Ñ è‘å¹…µ¥QåÁ•M¥é”¹¥Í•ÍÍ¥‰¥±¥ÑåM¥é”€ü€¹¥¹™¥¹¥Ñä€è€ÈĞÀ¤(€€€€€€€€€€€€€€€ô(€€€€€€€€€€€€€€€€¹‰ÕÑÑ½¹MÑå±”¡•¹Ñ	ÕÑÑ½¹MÑå±” ¤¤(€€€€€€€€€€€ô(€€€€€€€ô(€€€€€€€€¹Á…‘‘¥¹œ Äà¤(€€€€€€€€¹™É…µ”¡µ…á]¥‘Ñ è€¹¥¹™¥¹¥Ñä¤(€€€€€€€€¹¥¹Ñ•±±¥•¹•…É¡Ñ¥¹ĞèÁÁQ¡•µ”¹‰É…¹‘å…¸°½É¹•ÉI…‘¥ÕÌè€ÈÈ¤(€€€€€€€€¹ÑÉ…¹Í¥Ñ¥½¸¡É•‘Õ•5½Ñ¥½¸€ü€¹½Á…¥Ñä€è€¹½Á…¥Ñä¹½µ‰¥¹•¡İ¥Ñ è€¹Í…±”¡Í…±”è€À¸äÜ¤¤¤(€€€ô)ô()ÍÑÉÕĞ•…ÑÕÉ•1½…‘¥¹MÑ…Ñ”èY¥•Üì(€€€¹Ù¥É½¹µ•¹Ğ¡p¹…•ÍÍ¥‰¥±¥ÑåI•‘Õ•5½Ñ¥½¸¤ÁÉ¥Ù…Ñ”Ù…ÈÉ•‘Õ•5½Ñ¥½¸(€€€±•ĞÑ¥Ñ±”èMÑÉ¥¹œ(€€€±•Ğµ•ÍÍ…”èMÑÉ¥¹œ((€€€Ù…È‰½‘äèÍ½µ”Y¥•Üì(€€€€€€€YMÑ…¬¡ÍÁ…¥¹œè€ÄĞ¤ì(€€€€€€€€€€€AÉ½É•ÍÍY¥•Ü ¤¹½¹ÑÉ½±M¥é” ¹±…É”¤¹Ñ¥¹Ğ¡ÁÁQ¡•µ”¹‰É…¹‘å…¸¤(€€€€€€€€€€€Q•áĞ¡Ñ¥Ñ±”¤¹™½¹Ğ¡ÁÁQ¡•µ”¹Í•Ñ¥½¹Q¥Ñ±•½¹Ğ¤¹™½É•É½Õ¹‘MÑå±”¡ÁÁQ¡•µ”¹Ñ•áÑAÉ¥µ…Éä¤(€€€€€€€€€€€Q•áĞ¡µ•ÍÍ…”¤¹™½¹Ğ¡ÁÁQ¡•µ”¹…ÁÑ¥½¹½¹Ğ¤¹™½É•É½Õ¹‘MÑå±”¡ÁÁQ¡•µ”¹Ñ•áÑM•½¹‘…Éä¤¹µÕ±Ñ¥±¥¹•Q•áÑ±¥¹µ•¹Ğ ¹•¹Ñ•È¤(€€€€€€€ô(€€€€€€€€¹Á…‘‘¥¹œ ÈØ¤(€€€€€€€€¹™É…µ”¡µ…á]¥‘Ñ è€¹¥¹™¥¹¥Ñä¤(€€€€€€€€¹¥¹Ñ•±±¥•¹•…É¡Ñ¥¹ĞèÁÁQ¡•µ”¹‰É…¹‘å…¸°½É¹•ÉI…‘¥ÕÌè€ÈÈ¤(€€€€€€€€¹ÑÉ…¹Í¥Ñ¥½¸¡É•‘Õ•5½Ñ¥½¸€ü€¹½Á…¥Ñä€è€¹½Á…¥Ñä¹½µ‰¥¹•¡İ¥Ñ è€¹Í…±”¡Í…±”è€À¸äà¤¤¤(€€€€€€€€¹…•ÍÍ¥‰¥±¥Ñå±•µ•¹Ğ¡¡¥±‘É•¸è€¹½µ‰¥¹”¤(€€€€€€€€¹…•ÍÍ¥‰¥±¥Ñå1…‰•° ‰p¡Ñ¥Ñ±”§¾ò1p¡µ•ÍÍ…”¤ˆ¤(€€€ô)ô()ÁÉ¥Ù…Ñ”ÍÑÉÕĞ••‘%¹™½M¡••ĞèY¥•Üì(€€€±•Ğ™••‘½Õ¹Ğè%¹Ğ(€€€¹Ù¥É½¹µ•¹Ğ¡p¹‘¥Íµ¥ÍÌ¤ÁÉ¥Ù…Ñ”Ù…È‘¥Íµ¥ÍÌ((€€€Ù…È‰½‘äèÍ½µ”Y¥•Üì(€€€€€€€9…Ù¥…Ñ¥½¹MÑ…¬ì(€€€€€€€€€€€YMÑ…¬¡ÍÁ…¥¹œè€ÄØ¤ì(€€€€€€€€€€€€€€€%µ…” ‰QÉ•¹‘I…‘…Èµ]•‰¡½½¬ˆ¤(€€€€€€€€€€€€€€€€€€€€¹É•Í¥é…‰±” ¤(€€€€€€€€€€€€€€€€€€€€¹Í…±•‘Q½¥±° ¤(€€€€€€€€€€€€€€€€€€€€¹™É…µ”¡¡•¥¡Ğè€ÄÔÀ¤(€€€€€€€€€€€€€€€€€€€€¹±¥ÁÁ• ¤(€€€€€€€€€€€€€€€€€€€€¹±¥ÁM¡…Á”¡I½Õ¹‘•‘I•Ñ…¹±”¡½É¹•ÉI…‘¥ÕÌè€ÈÀ°ÍÑå±”è€¹½¹Ñ¥¹Õ½ÕÌ¤¤(€€€€€€€€€€€€€€€%µ…”¡ÍåÍÑ•µ9…µ”è€‰…¹Ñ•¹¹„¹É…‘¥½İ…Ù•Ì¹±•™Ğ¹…¹¹É¥¡Ğˆ¤(€€€€€€€€€€€€€€€€€€€€¹™½¹Ğ ¹ÍåÍÑ•´¡Í¥é”è€ÌĞ°İ•¥¡Ğè€¹±¥¡Ğ¤¤(€€€€€€€€€€€€€€€€€€€€¹™½É•É½Õ¹‘MÑå±”¡ÁÁQ¡•µ”¹å…¸¤(€€€€€€€€€€€€€€€Q•áĞ ‹–ŞË–B¿R p¡™••‘½Õ¹Ğ¤ƒ’â«¢º‹¦bšê@ˆ¤(€€€€€€€€€€€€€€€€€€€€¹™½¹Ğ¡ÁÁQ¡•µ”¹Í•Ñ¥½¹Q¥Ñ±•½¹Ğ¤(€€€€€€€€€€€€€€€€€€€€¹™½É•É½Õ¹‘MÑå±”¡ÁÁQ¡•µ”¹Ñ•áÑAÉ¥µ…Éä¤(€€€€€€€€€€€€€€€Q•áĞ ‰IMLƒ’â8Ñ½´ƒ––ºç’òk–r£–"ßšZÃš^Û–æÛ–>Gš*O–>[¾ò3–æÛ’şw–¶c–"Ãšr³–rÃšš*—–êOˆ¤(€€€€€€€€€€€€€€€€€€€€¹™½¹Ğ¡ÁÁQ¡•µ”¹‰½‘å½¹Ğ¤(€€€€€€€€€€€€€€€€€€€€¹™½É•É½Õ¹‘MÑå±”¡ÁÁQ¡•µ”¹Ñ•áÑM•½¹‘…Éä¤(€€€€€€€€€€€€€€€€€€€€¹µÕ±Ñ¥±¥¹•Q•áÑ±¥¹µ•¹Ğ ¹•¹Ñ•È¤(€€€€€€€€€€€€€€€€€€€€¹Á…‘‘¥¹œ ¹¡½É¥é½¹Ñ…°°€ÈĞ¤(€€€€€€€€€€€€€€€MÁ…•È ¤(€€€€€€€€€€€ô(€€€€€€€€€€€€¹Á…‘‘¥¹œ ¹Ñ½À°€Ğà¤(€€€€€€€€€€€€¹™É…µ”¡µ…á]¥‘Ñ è€¹¥¹™¥¹¥Ñä¤(€€€€€€€€€€€€¹‰…­É½Õ¹¡%¹Ñ•±±¥•¹•MÉ••¹	…­É½Õ¹ ¤¤(€€€€€€€€€€€€¹Ñ½½±‰…Èì(€€€€€€€€€€€€€€€Q½½±‰…É%Ñ•´¡Á±…•µ•¹Ğè€¹½¹™¥Éµ…Ñ¥½¹Ñ¥½¸¤ì	ÕÑÑ½¸ ‹–º3š"@ˆ¤ì‘¥Íµ¥ÍÌ ¤ôô(€€€€€€€€€€€ô(€€€€€€€ô(€€€€€€€€¹Ñ¥¹Ğ¡ÁÁQ¡•µ”¹å…¸¤(€€€ô)ô(