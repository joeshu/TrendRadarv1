import SwiftUI

struct ReportGeneratorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: ReportType = .daily
    let onGenerate: (ReportType) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("报告类型") {
                    Picker("类型", selection: $selectedType) {
                        ForEach(ReportType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    Text("生成时会先在手机端采集热榜与 RSS，再按当前筛选、排序和 AI 设置形成报告。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("生成报告")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("生成") {
                        onGenerate(selectedType)
                        dismiss()
                    }
                }
            }
            .preferredColorScheme(.dark)
            .tint(AppTheme.cyan)
        }
    }
}

struct ReportSummaryCard: View {
    let report: ReportSummary

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: report.isFavorite ? "star.fill" : "doc.text")
                .foregroundStyle(report.isFavorite ? AppTheme.yellow : AppTheme.pink)
            VStack(alignment: .leading, spacing: 4) {
                Text(report.title)
                    .font(AppTheme.headlineFont)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(report.type.displayName)
                    Text("·")
                    Text("\(report.newsCount) 条情报")
                    Text("·")
                    Text(report.generatedAt, style: .relative)
                }
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textTertiary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .padding(12)
        .background(AppTheme.card)
        .overlay(alignment: .topTrailing) {
            Text(report.hasAIAnalysis ? "已分析" : "本地快照")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(report.hasAIAnalysis ? AppTheme.cyan : AppTheme.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background((report.hasAIAnalysis ? AppTheme.cyan : AppTheme.textTertiary).opacity(0.12))
                .clipShape(Capsule())
                .padding(10)
        }
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct ReportDetailView: View {
    @EnvironmentObject private var reportStore: ReportStore
    @Environment(\.dismiss) private var dismiss
    let reportID: UUID
    @State private var report: ReportDetail?
    @State private var showingDeleteConfirmation = false

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            if let report {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        detailHeader(report)
                        statistics(report)
                        if let analysis = report.aiAnalysis, analysis.hasContent {
                            InsightPanel(title: "AI 洞察", icon: "sparkles", tint: AppTheme.cyan) {
                                VStack(alignment: .leading, spacing: 12) {
                                    analysisBlock(title: "核心热点态势", content: analysis.coreTrends ?? analysis.content)
                                    analysisBlock(title: "舆论风向争议", content: analysis.sentimentControversy)
                                    analysisBlock(title: "异动与弱信号", content: analysis.signals ?? analysis.weakSignals.joined(separator: "\n"))
                                    analysisBlock(title: "RSS 深度洞察", content: analysis.rssInsights)
                                    if let positive = analysis.sentimentPositive,
                                       let neutral = analysis.sentimentNeutral,
                                       let negative = analysis.sentimentNegative {
                                        HStack(spacing: 8) {
                                            SentimentPill(label: "正面", value: positive, tint: AppTheme.green)
                                            SentimentPill(label: "中性", value: neutral, tint: AppTheme.yellow)
                                            SentimentPill(label: "负面", value: negative, tint: AppTheme.red)
                                        }
                                    }
                                    if analysis.signals == nil && !analysis.weakSignals.isEmpty {
                                        Text("弱信号：" + analysis.weakSignals.joined(separator: "、"))
                                            .font(AppTheme.captionFont)
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }
                                    if let recommendation = analysis.recommendation, !recommendation.isEmpty {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("研判策略建议")
                                                .font(AppTheme.headlineFont)
                                                .foregroundStyle(AppTheme.cyan)
                                            Text(recommendation)
                                                .font(AppTheme.captionFont)
                                                .foregroundStyle(AppTheme.textSecondary)
                                        }
                                    }
                                    if !analysis.standaloneSummaries.isEmpty {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("独立源点速览")
                                                .font(AppTheme.headlineFont)
                                                .foregroundStyle(AppTheme.cyan)
                                            ForEach(analysis.standaloneSummaries.keys.sorted(), id: \.self) { source in
                                                if let summary = analysis.standaloneSummaries[source], !summary.isEmpty {
                                                    Text("[\(source)] \(summary)")
                                                        .font(AppTheme.captionFont)
                                                        .foregroundStyle(AppTheme.textSecondary)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        } else if let message = report.aiAnalysis?.failureMessage {
                            InsightPanel(title: "AI 洞察", icon: "exclamationmark.triangle", tint: AppTheme.yellow) {
                                Text(message).font(AppTheme.captionFont).foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                        ForEach(report.sections) { section in
                            sectionView(section)
                        }
                    }
                    .padding(20)
                }
            } else {
                FeatureEmptyState(icon: "doc.text.magnifyingglass", title: "报告不可用", message: "这份报告可能已被删除。")
            }
        }
        .navigationTitle("报告详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let report {
                    Menu {
                        ShareLink(item: ReportFormatter().render(report, format: .markdown)) {
                            Label("分享 Markdown", systemImage: "square.and.arrow.up")
                        }
                        ShareLink(item: ReportHTMLExport(report: report), preview: SharePreview(report.title, image: Image(systemName: "doc.richtext"))) {
                            Label("导出 HTML 报告", systemImage: "doc.richtext")
                        }
                        Button { Task { await reportStore.toggleFavorite(id: report.id); await loadReport() } } label: {
                            Label(report.isFavorite ? "取消收藏" : "收藏", systemImage: report.isFavorite ? "star.slash" : "star")
                        }
                        Button(role: .destructive) { showingDeleteConfirmation = true } label: {
                            Label("删除报告", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .confirmationDialog("删除这份报告？", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                Task {
                    await reportStore.delete(id: reportID)
                    dismiss()
                }
            }
        }
        .task { await loadReport() }
    }

    private func loadReport() async {
        report = await reportStore.detail(id: reportID)
    }

    @ViewBuilder
    private func analysisBlock(title: String, content: String?) -> some View {
        if let content, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTheme.headlineFont)
                    .foregroundStyle(AppTheme.cyan)
                Text(content)
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private func detailHeader(_ report: ReportDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(report.type.displayName.uppercased())
                        .font(AppTheme.captionFont)
                        .tracking(1.4)
                        .foregroundStyle(AppTheme.pink)
                    Text(report.title)
                        .font(AppTheme.titleFont)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("生成于 \(report.generatedAt, format: .dateTime.year().month().day().hour().minute())")
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textTertiary)
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
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func statistics(_ report: ReportDetail) -> some View {
        HStack(spacing: 12) {
            InsightMetric(value: "\(report.statistics.newsCount)", label: "情报", tint: AppTheme.cyan)
            InsightMetric(value: "\(report.statistics.sourceCount)", label: "来源", tint: AppTheme.yellow)
            InsightMetric(value: "\(report.statistics.unreadCount)", label: "未读", tint: AppTheme.pink)
            InsightMetric(value: "\(report.statistics.keywordCount)", label: "关键词", tint: AppTheme.green)
        }
        .padding(16)
        .background(AppTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func sectionView(_ section: ReportSection) -> some View {
        InsightPanel(title: section.title, icon: "list.bullet.rectangle", tint: AppTheme.yellow) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(section.items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(AppTheme.headlineFont)
                            .foregroundStyle(.white)
                        Text("\(item.source) · \(item.publishedAt?.relativeDescription ?? "刚刚")")
                            .font(AppTheme.captionFont)
                            .foregroundStyle(AppTheme.textTertiary)
                        if let rank = item.rank {
                            Text(rank <= reportRankThreshold ? "高热度排名：第\(rank)" : "排名：第\(rank)")
                                .font(AppTheme.captionFont)
                                .foregroundStyle(rank <= reportRankThreshold ? AppTheme.pink : AppTheme.textTertiary)
                        }
                        if let summary = item.summary, !summary.isEmpty {
                            Text(summary)
                                .font(AppTheme.captionFont)
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(2)
                        }
                        if let url = item.url {
                            Link("打开原文", destination: url)
                                .font(AppTheme.captionFont)
                                .foregroundStyle(AppTheme.cyan)
                        }
                    }
                    if item.id != section.items.last?.id {
                        Divider().overlay(Color.white.opacity(0.08))
                    }
                }
            }
        }
    }

    private var reportRankThreshold: Int {
        report?.settingsSnapshot.rankThreshold ?? 5
    }
}

private struct SentimentPill: View {
    let label: String
    let value: Double
    let tint: Color

    var body: some View {
        VStack(spacing: 3) {
            Text("\(Int(value * 100))%")
                .font(AppTheme.headlineFont)
                .foregroundStyle(tint)
            Text(label)
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(tint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
