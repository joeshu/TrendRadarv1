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
                    Text("报告只使用当前手机本地已经抓取的新闻内容。")
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
                Text("\(report.type.displayName) · \(report.newsCount) 条情报 · \(report.generatedAt, style: .relative)")
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
                                Text(analysis.content ?? "")
                                    .font(AppTheme.bodyFont)
                                    .foregroundStyle(AppTheme.textSecondary)
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

    private func detailHeader(_ report: ReportDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(report.type.displayName.uppercased())
                .font(AppTheme.captionFont)
                .tracking(1.4)
                .foregroundStyle(AppTheme.pink)
            Text(report.title)
                .font(AppTheme.titleFont)
                .foregroundStyle(.white)
            Text("生成于 \(report.generatedAt, format: .dateTime.year().month().day().hour().minute())")
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textTertiary)
        }
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
}
