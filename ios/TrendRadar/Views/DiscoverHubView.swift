import SwiftUI

struct DiscoverHubView: View {
    @EnvironmentObject private var store: NewsStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var hotNewsStore: HotNewsStore
    @EnvironmentObject private var reportStore: ReportStore
    @State private var mode = 0
    @State private var query = ""
    @State private var showingFeeds = false

    private var filtered: [NewsItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return Array(store.items.prefix(30)) }
        return store.items.filter { $0.title.localizedCaseInsensitiveContains(q) || $0.source.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        PremiumSectionHeader(eyebrow: "DISCOVER", title: "发现中心", subtitle: "阅读订阅内容，查看本地洞察", icon: "sparkles", tint: AppTheme.brandCyan)
                        Picker("内容", selection: $mode) {
                            Text("订阅").tag(0)
                            Text("洞察").tag(1)
                        }.pickerStyle(.segmented)
                        if mode == 0 { feedContent } else { insightContent }
                    }.padding(20)
                }
            }
            .navigationTitle("发现")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingFeeds = true } label: { Image(systemName: "slider.horizontal.3") }
                }
            }
            .sheet(isPresented: $showingFeeds) { FeedsView() }
        }
    }

    private var feedContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(AppTheme.brandCyan)
                TextField("搜索标题或来源", text: $query).textFieldStyle(.plain)
                if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }.foregroundStyle(.secondary) }
            }.padding(13).background(AppTheme.card).clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            HStack(spacing: 8) {
                PremiumMetricCard(value: "\(store.items.count)", label: "文章", icon: "newspaper", tint: AppTheme.brandCyan)
                PremiumMetricCard(value: "\(Set(store.items.map { $0.source }).count)", label: "来源", icon: "antenna.radiowaves.left.and.right", tint: AppTheme.brandIndigo)
            }
            if filtered.isEmpty { FeatureEmptyState(icon: "newspaper", title: "暂无订阅内容", message: "刷新 RSS 或检查订阅源配置") }
            else { ForEach(filtered) { item in CompactFeedCard(item: item) } }
        }
    }

    private var insightContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            PremiumPanel(tint: AppTheme.brandMagenta) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("本地洞察", systemImage: "sparkles").foregroundStyle(AppTheme.brandMagenta)
                    Text("基于当前 RSS、热榜和已保存报告生成分析。\n不引入虚构指标，只展示真实采集结果。")
                        .font(AppTheme.bodyFont).foregroundStyle(AppTheme.textSecondary)
                }
            }
            NavigationLink { InsightView() } label: {
                Label("打开完整洞察", systemImage: "arrow.up.right").frame(maxWidth: .infinity)
            }.buttonStyle(AccentButtonStyle())
            if let report = reportStore.reports.first {
                PremiumPanel(tint: AppTheme.brandCyan) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("最近报告").font(AppTheme.captionFont).foregroundStyle(AppTheme.brandCyan)
                        Text(report.title).font(AppTheme.headlineFont).foregroundStyle(.white)
                        Text(report.generatedAt.formatted(date: .abbreviated, time: .shortened)).font(AppTheme.captionFont).foregroundStyle(AppTheme.textTertiary)
                    }
                }
            }
        }
    }
}
