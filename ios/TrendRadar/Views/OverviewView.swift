import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var store: NewsStore
    @EnvironmentObject private var hotNewsStore: HotNewsStore
    @EnvironmentObject private var reportStore: ReportStore
    @State private var showingSettings = false
    @State private var isRefreshing = false
    @State private var refreshMessage: String?

    private var failureCount: Int { store.sourceFailures.count + hotNewsStore.sourceFailures.count }
    private var digest: TodayDigest { TodayDigestBuilder.build(news: store.items, topics: hotNewsStore.topics, failureCount: failureCount) }
    private var lastUpdated: Date? { [store.lastUpdated, hotNewsStore.lastUpdated].compactMap { $0 }.max() }
    private var latestReport: ReportSummary? { reportStore.reports.max { $0.generatedAt < $1.generatedAt } }

    var body: some View {
        NavigationStack {
            IntelligencePage {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        header
                        briefing
                        metrics
                        topicSection(title: "前三趋势", subtitle: "按当前最佳真实排名", icon: "chart.line.uptrend.xyaxis", topics: digest.topTopics)
                        topicSection(title: "快速升温", subtitle: "排名较上次采集提升", icon: "arrow.up.right", topics: digest.risingTopics)
                        if !digest.followedTopics.isEmpty {
                            topicSection(title: "关注主题", subtitle: "你主动标记的趋势", icon: "star.fill", topics: digest.followedTopics)
                        }
                        sourceStatus
                        recentReport
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 120)
                }
                .refreshable { await refresh() }
            }
            .navigationTitle("今日")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: HotNewsTopic.self) { HotNewsTrendView(topic: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { Task { await refresh() } } label: { Label("立即刷新", systemImage: "arrow.clockwise") }
                        Button { showingSettings = true } label: { Label("设置", systemImage: "gearshape") }
                    } label: {
                        Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("今日页工具")
                }
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .task {
                await reloadStores()
                if store.items.isEmpty && hotNewsStore.items.isEmpty { await refresh() }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Date.now.formatted(.dateTime.month(.wide).day().weekday(.wide)))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.brandCyan)
            Text("今日情报简报")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
            Label(isRefreshing ? "正在刷新本机数据" : lastUpdated.map { "更新于 \($0.formatted(date: .omitted, time: .shortened))" } ?? "等待首次刷新", systemImage: isRefreshing ? "arrow.triangle.2.circlepath" : "clock")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var briefing: some View {
        PremiumPanel(tint: failureCount == 0 ? AppTheme.brandCyan : AppTheme.yellow) {
            VStack(alignment: .leading, spacing: 12) {
                PremiumSectionHeader(eyebrow: "LOCAL BRIEF", title: "本机摘要", subtitle: "基于当前缓存与本轮采集结果", icon: "text.alignleft", tint: AppTheme.brandCyan)
                Text(digest.briefing)
                    .font(.body)
                    .foregroundStyle(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let refreshMessage {
                    Label(refreshMessage, systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(AppTheme.yellow)
                }
            }
        }
    }

    private var metrics: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                TodayMetric(value: "\(digest.newsCount)", label: "订阅情报", icon: "newspaper", tint: AppTheme.brandCyan)
                TodayMetric(value: "\(digest.unreadCount)", label: "未处理", icon: "circle.fill", tint: AppTheme.brandIndigo)
                TodayMetric(value: "\(hotNewsStore.topics.count)", label: "趋势主题", icon: "waveform.path.ecg", tint: AppTheme.green)
                TodayMetric(value: "\(failureCount)", label: "来源异常", icon: "exclamationmark.triangle", tint: failureCount == 0 ? AppTheme.green : AppTheme.yellow)
            }
        }
    }

    @ViewBuilder
    private func topicSection(title: String, subtitle: String, icon: String, topics: [HotNewsTopic]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            PremiumSectionHeader(title: title, subtitle: subtitle, icon: icon, tint: AppTheme.brandCyan)
            if topics.isEmpty {
                Text("暂无符合条件的真实趋势，等待后续采集。")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.vertical, 12)
            } else {
                ForEach(topics) { topic in
                    NavigationLink(value: topic) { TodayTrendRow(topic: topic) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private var sourceStatus: some View {
        VStack(alignment: .leading, spacing: 12) {
            PremiumSectionHeader(title: "来源状态", subtitle: failureCount == 0 ? "本轮未发现采集异常" : "失败来源继续使用可用缓存", icon: "antenna.radiowaves.left.and.right", tint: failureCount == 0 ? AppTheme.green : AppTheme.yellow)
            if failureCount == 0 {
                StatusBadge(title: "来源正常", systemImage: "checkmark.circle.fill", tint: AppTheme.green)
            } else {
                ForEach(Array(Set(store.sourceFailures + hotNewsStore.sourceFailures)).sorted(), id: \.self) { source in
                    SourceHealthBanner(title: source, detail: store.sourceFailureDetails[source] ?? hotNewsStore.sourceFailureDetails[source] ?? "本轮刷新失败", tint: AppTheme.yellow)
                }
            }
        }
    }

    private var recentReport: some View {
        VStack(alignment: .leading, spacing: 12) {
            PremiumSectionHeader(title: "最近报告", subtitle: "保存在本机的最新报告", icon: "doc.text", tint: AppTheme.brandIndigo)
            if let report = latestReport {
                NavigationLink {
                    ReportDetailView(reportID: report.id)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text.fill")
                            .foregroundStyle(AppTheme.brandIndigo)
                            .frame(width: 44, height: 44)
                            .background(AppTheme.brandIndigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(report.title).font(.headline).foregroundStyle(AppTheme.textPrimary).lineLimit(2)
                            Text("\(report.newsCount) 条 · \(report.generatedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption).foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(AppTheme.textTertiary)
                    }
                    .padding(14)
                    .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                Text("刷新并生成报告后，会在这里显示最近结果。")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        refreshMessage = nil
        defer { isRefreshing = false }
        do {
            _ = try await RefreshPipelineExecutor.shared.execute(context: PipelineExecutionContext(trigger: .manual))
            await reloadStores()
        } catch {
            refreshMessage = "刷新失败，当前继续显示本机缓存：\(error.localizedDescription)"
            await reloadStores()
        }
    }

    private func reloadStores() async {
        await store.load()
        await hotNewsStore.load()
        await reportStore.load()
    }
}

private struct TodayMetric: View {
    let value: String
    let label: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: icon).font(.caption.weight(.semibold)).foregroundStyle(tint)
            Text(value).font(.title2.bold().monospacedDigit()).foregroundStyle(AppTheme.textPrimary)
        }
        .frame(width: 120, alignment: .leading)
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(tint.opacity(0.22), lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }
}

private struct TodayTrendRow: View {
    let topic: HotNewsTopic

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(topic.bestRank)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(topic.strongestTrend == .up ? AppTheme.green : AppTheme.brandCyan)
                .frame(width: 48, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Text(topic.title).font(.headline).foregroundStyle(AppTheme.textPrimary).lineLimit(2)
                Text("\(topic.platformCount) 个平台 · \(topic.strongestTrend.todayLabel)")
                    .font(.caption).foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").foregroundStyle(AppTheme.textTertiary)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private extension HotNewsTrend {
    var todayLabel: String {
        switch self {
        case .up: return "上升"
        case .down: return "回落"
        case .stable: return "稳定"
        case .new: return "新进"
        }
    }
}
