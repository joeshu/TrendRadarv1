import SwiftUI

struct ReportGeneratorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: ReportType = .daily
    @State private var timeRange = 1
    @State private var includeRSS = true
    @State private var includeHotlist = true
    @State private var reportLength = 1
    @State private var analysisDepth = 1
    @State private var outputLanguage = "中文"
    let onGenerate: (ReportType, Date?, Bool, Bool, Int, Int, String) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                IntelligenceScreenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        IntelligencePageHeader(
                            eyebrow: "NEW REPORT",
                            title: "生成一份新的趋势报告",
                            subtitle: "先采集当前热榜与 RSS，再生成可保存的新闻快照",
                            icon: "doc.badge.plus",
                            assetName: "TrendRadar-ReportsHero"
                        )
                        VStack(alignment: .leading, spacing: 14) {
                            Label("报告类型", systemImage: "doc.text.magnifyingglass")
                                .font(AppTheme.cardTitleFont)
                                .foregroundStyle(AppTheme.textPrimary)
                            Picker("类型", selection: $selectedType) {
                                ForEach(ReportType.allCases, id: \.self) { type in
                                    Text(type.displayName).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                            Text("报告会保存生成时的热榜、RSS、筛选结果与 AI 分析。")
                                .font(AppTheme.captionFont)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding(18)
                        .intelligenceCard(tint: AppTheme.brandIndigo, cornerRadius: 20)
                        VStack(alignment: .leading, spacing: 14) {
                            Label("证据范围", systemImage: "scope")
                                .font(AppTheme.cardTitleFont).foregroundStyle(AppTheme.textPrimary)
                            Picker("时间范围", selection: $timeRange) {
                                Text("当前").tag(0); Text("24 小时").tag(1); Text("7 天").tag(7); Text("30 天").tag(30)
                            }.pickerStyle(.segmented)
                            Toggle("包含 RSS 内容", isOn: $includeRSS)
                            Toggle("包含热榜内容", isOn: $includeHotlist)
                            HStack {
                                Label("地域", systemImage: "globe.asia.australia").foregroundStyle(AppTheme.textSecondary)
                                Spacer(); Text("跟随真实来源").foregroundStyle(AppTheme.textTertiary)
                            }.font(AppTheme.captionFont)
                        }
                        .padding(18)
                        .intelligenceCard(tint: AppTheme.brandCyan, cornerRadius: 20)
                        VStack(alignment: .leading, spacing: 14) {
                            Label("报告偏好", systemImage: "slider.horizontal.3")
                                .font(AppTheme.cardTitleFont).foregroundStyle(AppTheme.textPrimary)
                            Picker("报告篇幅", selection: $reportLength) {
                                Text("精简").tag(0); Text("标准").tag(1); Text("详细").tag(2)
                            }.pickerStyle(.segmented)
                            Picker("分析深度", selection: $analysisDepth) {
                                Text("常规").tag(0); Text("深入").tag(1); Text("专家").tag(2)
                            }.pickerStyle(.segmented)
                            Picker("输出语言", selection: $outputLanguage) {
                                Text("中文").tag("中文"); Text("English").tag("English"); Text("日本語").tag("日本語")
                            }
                        }
                        .padding(18)
                        .intelligenceCard(tint: AppTheme.brandMagenta, cornerRadius: 20)
                        Button {
                            onGenerate(selectedType, windowStart, includeRSS, includeHotlist, reportLength, analysisDepth, outputLanguage)
                            dismiss()
                        } label: {
                            Label("生成报告", systemImage: "sparkles").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AccentButtonStyle())
                        .disabled(!includeRSS && !includeHotlist)
                    }
                    .padding(16)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("生成报告")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("生成") {
                        onGenerate(selectedType, windowStart, includeRSS, includeHotlist, reportLength, analysisDepth, outputLanguage)
                        dismiss()
                    }.disabled(!includeRSS && !includeHotlist)
                }
            }
            .tint(AppTheme.cyan)
        }
    }

    private var windowStart: Date? {
        guard timeRange > 0 else { return nil }
        return Calendar.current.date(byAdding: .day, value: -timeRange, to: Date())
    }
}

struct ReportSummaryCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let report: ReportSummary

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill((report.isFavorite ? AppTheme.yellow : AppTheme.brandCyan).opacity(0.12))
                Image(systemName: report.isFavorite ? "star.fill" : "doc.text")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(report.isFavorite ? AppTheme.yellow : AppTheme.brandCyan)
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 5) {
                Text(report.title).font(AppTheme.cardTitleFont).foregroundStyle(AppTheme.textPrimary).lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                HStack(spacing: 6) {
                    Text(report.type.displayName); Text("·"); Text("\(report.newsCount) 条情报"); Text("·"); Text(report.generatedAt, style: .relative)
                    if dynamicTypeSize.isAccessibilitySize { Text("·"); Text(report.hasAIAnalysis ? "已分析" : "本地快照") }
                }
                .font(AppTheme.captionFont).foregroundStyle(AppTheme.textTertiary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(AppTheme.textTertiary)
        }
        .padding(12)
        .intelligenceCard(tint: report.isFavorite ? AppTheme.yellow : AppTheme.brandCyan, cornerRadius: 14)
        .overlay(alignment: .topTrailing) {
            if !dynamicTypeSize.isAccessibilitySize {
                Text(report.hasAIAnalysis ? "已分析" : "本地快照")
                    .font(AppTheme.metadataFont)
                    .foregroundStyle(report.hasAIAnalysis ? AppTheme.cyan : AppTheme.textTertiary)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background((report.hasAIAnalysis ? AppTheme.cyan : AppTheme.textTertiary).opacity(0.12))
                    .clipShape(Capsule()).padding(10)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(report.title)，\(report.type.displayName)，\(report.newsCount) 条情报，\(report.hasAIAnalysis ? "已分析" : "本地快照")")
    }
}

struct ReportDetailView: View {
    @EnvironmentObject private var reportStore: ReportStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @Environment(\.dismiss) private var dismiss
    let reportID: UUID
    @State private var report: ReportDetail?
    @State private var showingDeleteConfirmation = false
    @State private var queryText = ""
    @State private var queryResult: InsightQueryResult?
    @State private var isQuerying = false
    @State private var isLoading = true
    @State private var actionFeedback: ActionFeedback?

    var body: some View {
        ZStack {
            IntelligenceScreenBackground()
            if let report {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        PageVisualBanner(assetName: "TrendRadar-ReportsHero", height: 128)
                        PremiumPanel(tint: AppTheme.brandCyan) { detailHeader(report) }
                        PremiumPanel(tint: AppTheme.brandIndigo) { statistics(report) }
                        evidencePanel(report)
                        reportQueryPanel(report)
                        if let analysis = report.aiAnalysis, analysis.hasContent {
                            PremiumPanel(tint: AppTheme.brandMagenta) {
                                VStack(alignment: .leading, spacing: 12) {
                                    PremiumSectionHeader(eyebrow: "AI INSIGHTS", title: "AI 洞察", subtitle: "结构化分析与趋势判断", icon: "sparkles", tint: AppTheme.brandMagenta)
                                    analysisBlock(title: "核心热点态势", content: analysis.coreTrends ?? analysis.content)
                                    analysisBlock(title: "舆论风向争议", content: analysis.sentimentControversy)
                                    analysisBlock(title: "异动与弱信号", content: analysis.signals ?? analysis.weakSignals.joined(separator: "\n"))
                                    analysisBlock(title: "RSS 深度洞察", content: analysis.rssInsights)
                                    if let positive = analysis.sentimentPositive, let neutral = analysis.sentimentNeutral, let negative = analysis.sentimentNegative {
                                        HStack(spacing: 8) {
                                            SentimentPill(label: "正面", value: positive, tint: AppTheme.green)
                                            SentimentPill(label: "中性", value: neutral, tint: AppTheme.yellow)
                                            SentimentPill(label: "负面", value: negative, tint: AppTheme.red)
                                        }
                                    }
                                    if let recommendation = analysis.recommendation, !recommendation.isEmpty {
                                        analysisBlock(title: "研判策略建议", content: recommendation)
                                    }
                                    if !analysis.standaloneSummaries.isEmpty {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("独立源点速览").font(AppTheme.headlineFont).foregroundStyle(AppTheme.cyan)
                                            ForEach(analysis.standaloneSummaries.keys.sorted(), id: \.self) { source in
                                                if let summary = analysis.standaloneSummaries[source], !summary.isEmpty { Text("[\(source)] \(summary)").font(AppTheme.captionFont).foregroundStyle(AppTheme.textSecondary) }
                                            }
                                        }
                                    }
                                }
                            }
                        } else if let message = report.aiAnalysis?.failureMessage {
                            InsightPanel(title: "AI 洞察", icon: "exclamationmark.triangle", tint: AppTheme.yellow) { Text(message).font(AppTheme.captionFont).foregroundStyle(AppTheme.textSecondary) }
                        }
                        if !report.newItems.isEmpty {
                            PremiumPanel(tint: AppTheme.brandCyan) {
                                VStack(alignment: .leading, spacing: 10) {
                                    PremiumSectionHeader(eyebrow: "NEW SIGNALS", title: "新增热点", subtitle: "本批次首次出现的内容", icon: "sparkles", tint: AppTheme.brandCyan)
                                    ForEach(report.newItems.prefix(8)) { item in
                                        HStack(alignment: .top, spacing: 8) {
                                            Circle().fill(AppTheme.brandCyan).frame(width: 6, height: 6).padding(.top, 6)
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(item.title).font(AppTheme.headlineFont).foregroundStyle(AppTheme.textPrimary)
                                                Text(item.source).font(AppTheme.captionFont).foregroundStyle(AppTheme.textTertiary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        ForEach(ReportPresentationModel(report: report).sections) { section in sectionView(section) }
                        if let diagnostics = report.diagnostics, !diagnostics.failures.isEmpty {
                            PremiumPanel(tint: AppTheme.yellow) {
                                VStack(alignment: .leading, spacing: 10) {
                                    PremiumSectionHeader(eyebrow: "SOURCE HEALTH", title: "采集异常", subtitle: "部分来源未能完成刷新", icon: "exclamationmark.triangle", tint: AppTheme.yellow)
                                    ForEach(diagnostics.failures) { failure in
                                        HStack(alignment: .top, spacing: 8) {
                                            Image(systemName: "xmark.circle.fill").foregroundStyle(AppTheme.yellow)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(failure.source).font(AppTheme.headlineFont).foregroundStyle(AppTheme.textPrimary)
                                                Text(failure.message).font(AppTheme.captionFont).foregroundStyle(AppTheme.textSecondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        Menu {
                            ShareLink(item: ReportFormatter().render(report, format: .markdown)) {
                                Label("分享 Markdown", systemImage: "doc.text")
                            }
                            ShareLink(item: ReportHTMLExport(report: report), preview: SharePreview(report.title, image: Image(systemName: "doc.richtext"))) {
                                Label("导出 HTML 报告", systemImage: "doc.richtext")
                            }
                        } label: {
                            Label("导出报告", systemImage: "square.and.arrow.up")
                                .font(AppTheme.cardTitleFont)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 50)
                        }
                        .buttonStyle(AccentButtonStyle())
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
            } else if isLoading {
                FeatureLoadingState(title: "正在加载报告", message: "读取本机快照与分析结果")
                    .padding(16)
            } else {
                FeatureEmptyState(icon: "doc.text.magnifyingglass", title: "报告不可用", message: "这份报告可能已被删除。")
                    .padding(16)
            }
        }
        .navigationTitle("报告详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let report {
                    Menu {
                        ShareLink(item: ReportFormatter().render(report, format: .markdown)) { Label("分享 Markdown", systemImage: "square.and.arrow.up") }
                        ShareLink(item: ReportHTMLExport(report: report), preview: SharePreview(report.title, image: Image(systemName: "doc.richtext"))) { Label("导出 HTML 报告", systemImage: "doc.richtext") }
                        NavigationLink {
                            ReportOutputPreviewView(settings: settingsStore.settings, reportID: report.id)
                        } label: {
                            Label("输出预览", systemImage: "eye")
                        }
                        Button { Task { await reportStore.toggleFavorite(id: report.id); await loadReport() } } label: { Label(report.isFavorite ? "取消收藏" : "收藏", systemImage: report.isFavorite ? "star.slash" : "star") }
                        Button(role: .destructive) { showingDeleteConfirmation = true } label: { Label("删除报告", systemImage: "trash") }
                    } label: { ToolbarIconLabel(systemName: "ellipsis.circle", label: "报告操作") }
                }
            }
        }
        .confirmationDialog("删除这份报告？", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("删除", role: .destructive) { Task { await reportStore.delete(id: reportID); dismiss() } }
        }
        .task { await loadReport() }
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

    private func loadReport() async {
        isLoading = true
        report = await reportStore.detail(id: reportID)
        isLoading = false
    }

    private func reportQueryPanel(_ report: ReportDetail) -> some View {
        InsightPanel(title: "向报告追问", icon: "bubble.left.and.text.bubble.right", tint: AppTheme.brandCyan) {
            VStack(alignment: .leading, spacing: 10) {
                TextField("例如：最值得关注的风险是什么？", text: $queryText, axis: .vertical)
                    .lineLimit(2...5)
                Button {
                    let question = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !question.isEmpty else { return }
                    isQuerying = true
                    actionFeedback = .progress("正在检索报告证据并生成回答")
                    Task {
                        defer { isQuerying = false }
                        do {
                            queryResult = try await AIService().query(question: question, report: report, settings: settingsStore.settings)
                            actionFeedback = .success("回答已生成，并校验了报告引用")
                        } catch {
                            actionFeedback = .failure("追问失败：\(error.localizedDescription)")
                        }
                    }
                } label: { Label(isQuerying ? "分析中" : "基于本报告回答", systemImage: "sparkles") }
                    .buttonStyle(OutlineButtonStyle()).disabled(isQuerying || queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if let result = queryResult {
                    ReportRichText(content: result.answer)
                    ForEach(result.citations) { citation in
                        if let url = citation.url {
                            Link("引用：\(citation.source) · \(citation.title)", destination: url)
                                .font(AppTheme.captionFont).foregroundStyle(AppTheme.brandCyan)
                        } else {
                            Text("引用：\(citation.source) · \(citation.title)").font(AppTheme.captionFont).foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func analysisBlock(title: String, content: String?) -> some View {
        if let content {
            let clean = content
                .replacingOccurrences(of: "\\r\\n", with: "\\n")
                .replacingOccurrences(of: "\\r", with: "\\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text(title).font(AppTheme.headlineFont).foregroundStyle(AppTheme.cyan)
                    ReportRichText(content: clean)
                }
            }
        }
    }

    private func detailHeader(_ report: ReportDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(report.type.displayName.uppercased()).font(AppTheme.captionFont).tracking(1.4).foregroundStyle(AppTheme.pink)
                    Text(report.title).font(AppTheme.titleFont).foregroundStyle(AppTheme.textPrimary).fixedSize(horizontal: false, vertical: true)
                    Text("生成于 \(report.generatedAt, format: .dateTime.year().month().day().hour().minute())").font(AppTheme.captionFont).foregroundStyle(AppTheme.textTertiary)
                }
                Spacer(minLength: 12)
                Image(systemName: report.aiAnalysis?.hasContent == true ? "sparkles" : "doc.text")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(report.aiAnalysis?.hasContent == true ? AppTheme.cyan : AppTheme.pink)
                    .frame(width: 46, height: 46)
                    .background((report.aiAnalysis?.hasContent == true ? AppTheme.cyan : AppTheme.pink).opacity(0.13))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(18)
        .background(AppTheme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func statistics(_ report: ReportDetail) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                InsightMetric(value: "\(report.statistics.newsCount)", label: "情报", tint: AppTheme.cyan)
                InsightMetric(value: "\(report.statistics.sourceCount)", label: "来源", tint: AppTheme.yellow)
                InsightMetric(value: "\(report.statistics.unreadCount)", label: "未读", tint: AppTheme.pink)
                InsightMetric(value: "\(report.statistics.keywordCount)", label: "关键词", tint: AppTheme.green)
            }
            HStack(spacing: 12) {
                InsightMetric(value: "\(report.statistics.hotlistCount)", label: "热榜", tint: AppTheme.yellow)
                InsightMetric(value: "\(report.statistics.rssCount)", label: "RSS", tint: AppTheme.cyan)
                InsightMetric(value: "\(report.statistics.hotlistPlatformCount)", label: "热榜平台", tint: AppTheme.pink)
                InsightMetric(value: "\(report.statistics.rssSourceCount)", label: "RSS 来源", tint: AppTheme.green)
            }
        }
        .padding(16)
        .intelligenceCard(tint: AppTheme.brandIndigo, cornerRadius: 16)
    }

    private func evidencePanel(_ report: ReportDetail) -> some View {
        let evidence = ReportPresentationModel(report: report).evidence
        return InsightPanel(title: "证据与范围", icon: evidence.isPartial ? "exclamationmark.shield" : "checkmark.shield", tint: evidence.isPartial ? AppTheme.yellow : AppTheme.green) {
            VStack(alignment: .leading, spacing: 10) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        evidenceBadges(evidence)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        evidenceBadges(evidence)
                    }
                }
                Text("样本 \(evidence.sampleCount) 条 · 命中 \(evidence.matchedCount) 条 · 来源 \(evidence.sourceCount) 个")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textSecondary)
                Text(evidenceWindow(evidence))
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textSecondary)
                Text("引用 \(evidence.citedItemCount) 条 · 失败来源 \(evidence.failedSourceCount) 个")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(evidence.failedSourceCount > 0 ? AppTheme.yellow : AppTheme.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("证据与范围，样本 \(evidence.sampleCount) 条，命中 \(evidence.matchedCount) 条，引用 \(evidence.citedItemCount) 条，失败来源 \(evidence.failedSourceCount) 个，\(evidence.generationMethod)")
        }
    }

    @ViewBuilder
    private func evidenceBadges(_ evidence: ReportEvidenceSummary) -> some View {
        StatusBadge(title: evidence.isPartial ? "部分完成" : "数据完整", systemImage: evidence.isPartial ? "exclamationmark.circle" : "checkmark.circle", tint: evidence.isPartial ? AppTheme.yellow : AppTheme.green)
        StatusBadge(title: evidence.generationMethod, systemImage: "gearshape.2", tint: AppTheme.cyan)
    }

    private func evidenceWindow(_ evidence: ReportEvidenceSummary) -> String {
        let end = evidence.windowEnd.formatted(date: .numeric, time: .shortened)
        guard let start = evidence.windowStart else { return "数据窗口：截至 \(end)" }
        return "数据窗口：\(start.formatted(date: .numeric, time: .shortened)) 至 \(end)"
    }

    private func sectionView(_ section: ReportSection) -> some View {
        InsightPanel(title: section.title, icon: "list.bullet.rectangle", tint: AppTheme.yellow) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(section.items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title).font(AppTheme.headlineFont).foregroundStyle(AppTheme.textPrimary)
                        Text("\(item.source) · \(item.publishedAt?.relativeDescription ?? "刚刚")").font(AppTheme.captionFont).foregroundStyle(AppTheme.textTertiary)
                        if let rank = item.rank { Text(rank <= reportRankThreshold ? "高热度排名：第\(rank)" : "排名：第\(rank)").font(AppTheme.captionFont).foregroundStyle(rank <= reportRankThreshold ? AppTheme.pink : AppTheme.textTertiary) }
                        if let summary = TextSanitizer.plainText(item.summary), !summary.isEmpty { Text(summary).font(AppTheme.captionFont).foregroundStyle(AppTheme.textSecondary).lineLimit(4) }
                        if let url = item.url { Link("打开原文", destination: url).font(AppTheme.captionFont).foregroundStyle(AppTheme.cyan) }
                    }
                    if item.id != section.items.last?.id { Divider().overlay(AppTheme.cardBorder) }
                }
            }
        }
    }

    private var reportRankThreshold: Int { report?.settingsSnapshot.rankThreshold ?? 5 }
}

private struct SentimentPill: View {
    let label: String
    let value: Double
    let tint: Color
    var body: some View {
        VStack(spacing: 3) {
            Text("\(Int(value * 100))%").font(AppTheme.headlineFont).foregroundStyle(tint)
            Text(label).font(AppTheme.captionFont).foregroundStyle(AppTheme.textTertiary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
        .background(tint.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
