import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct ReportHTMLExport: Transferable {
    let report: ReportDetail

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .html) { export in
            Data(ReportHTMLFormatter().render(export.report).utf8)
        }
        .suggestedFileName { export in "TrendRadar-\(export.report.id.uuidString).html" }
    }
}

struct ReportHTMLFormatter {
    func render(_ report: ReportDetail) -> String {
        let model = ReportPresentationModel(report: report)
        let evidence = model.evidence
        let analysis = renderAI(report.aiAnalysis)
        let newItems = renderNewItems(report.newItems)
        let sections = model.sections.map(renderSection).joined()
        let failures = renderFailures(report.diagnostics)
        let topicStats = renderTopicStats(report.topicStats)
        let completeness = report.metadata.isPartial ? "部分完成" : "完整"
        let evidencePanel = renderEvidence(evidence)
        let stats = [
            ("情报", report.statistics.newsCount, "条", "cyan"),
            ("热榜", report.statistics.hotlistCount, "条", "yellow"),
            ("RSS", report.statistics.rssCount, "条", "pink"),
            ("来源", report.statistics.sourceCount, "个", "green")
        ].map { "<div class=\"stat \($0.3)\"><strong>\($0.1)</strong><span>\($0.0) · \($0.2)</span></div>" }.joined()
        return """
        <!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>\(escape(report.title))</title><style>
        :root{color-scheme:dark;--bg:#080d18;--card:#111a2b;--line:#24324b;--text:#f4f7ff;--muted:#9aa9c2;--cyan:#62e6ff;--pink:#ff76b6;--yellow:#ffd166;--green:#65e6a1}*{box-sizing:border-box}body{margin:0;background:radial-gradient(circle at 10% 0,#172d4a 0,#080d18 42%);color:var(--text);font:15px/1.7 -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif}.page{max-width:820px;margin:auto;padding:22px}.hero{padding:28px;border:1px solid #31466b;border-radius:24px;background:linear-gradient(135deg,#182c52,#251b48 70%,#351d48);box-shadow:0 16px 50px #0005}h1{margin:0 0 8px;font-size:clamp(24px,5vw,38px);line-height:1.25}.meta{color:var(--muted)}.stats{display:grid;grid-template-columns:repeat(4,1fr);gap:10px;margin:18px 0}.stat{padding:14px;border:1px solid var(--line);border-radius:16px;background:#101a2b}.stat strong{display:block;font-size:24px}.stat span{color:var(--muted);font-size:12px}.cyan strong,h2.cyan{color:var(--cyan)}.yellow strong{color:var(--yellow)}.pink strong{color:var(--pink)}.green strong{color:var(--green)}section.panel{margin:18px 0;padding:20px;border:1px solid var(--line);border-radius:20px;background:#0e1727cc}h2{margin:0 0 14px;color:var(--cyan);font-size:21px}h3{margin:0;color:var(--text);font-size:17px}article{padding:14px 0;border-bottom:1px solid var(--line)}article:last-child{border-bottom:0}.item-meta{color:var(--muted);font-size:12px}.rank{float:right;color:var(--yellow);font-weight:700}a{color:var(--cyan);text-decoration:none}p{white-space:pre-wrap;margin:7px 0;color:#c5d0e3}.badge{display:inline-block;padding:2px 8px;border-radius:99px;background:#ff76b622;color:var(--pink);font-size:11px}.failure{color:#ff9b9b}.footer{margin:24px 4px;color:var(--muted);font-size:12px}@media(max-width:560px){.page{padding:12px}.stats{grid-template-columns:repeat(2,1fr)}}
        </style></head><body><div class="page"><header class="hero"><h1>\(escape(report.title))</h1><div class="meta">TrendRadar · \(escape(report.type.displayName)) · 生成于 \(escape(date(report.generatedAt))) · 数据完整度：\(completeness)</div></header><div class="stats">\(stats)</div>\(evidencePanel)\(topicStats)\(analysis)\(newItems)\(sections)\(failures)<div class="footer">报告 ID：\(report.id.uuidString) · 协议 v\(report.metadata.schemaVersion) · App \(escape(report.metadata.appVersion)) · 时区 \(escape(report.metadata.timeZone)) · 共 \(report.sections.flatMap(\.items).count) 条</div></div></body></html>
        """
    }

    private func renderEvidence(_ evidence: ReportEvidenceSummary) -> String {
        let window = evidence.windowStart.map { "\(date($0)) 至 \(date(evidence.windowEnd))" } ?? "截至 \(date(evidence.windowEnd))"
        return "<section class=\"panel\"><h2>证据与范围</h2><p>样本 \(evidence.sampleCount) 条 · 命中 \(evidence.matchedCount) 条 · 来源 \(evidence.sourceCount) 个</p><p>数据窗口：\(escape(window))</p><p>引用 \(evidence.citedItemCount) 条 · 失败来源 \(evidence.failedSourceCount) 个 · \(escape(evidence.generationMethod))</p></section>"
    }

    private func renderTopicStats(_ stats: [ReportTopicStat]) -> String {
        guard !stats.isEmpty else { return "" }
        let rows = stats.map { stat in
            "<article><h3>\(escape(stat.name))</h3><div class=\"item-meta\">\(stat.count) 条 · \(Int((stat.percentage * 100).rounded()))% · 热度 \(escape(stat.level))</div></article>"
        }.joined()
        return "<section class=\"panel\"><h2>🔥 热点词汇统计</h2>\(rows)</section>"
    }

    private func renderSection(_ section: ReportSection) -> String {
        let rows = section.items.map { item in
            let title = item.url.map { "<a href=\"\(escape($0.absoluteString))\">\(escape(item.title))</a>" } ?? escape(item.title)
            let rank = item.rank.map { "<span class=\"rank\">#\($0)</span>" } ?? ""
            let meta = "\(escape(item.source))" + (item.publishedAt.map { " · \(escape(date($0)))" } ?? "") + (item.rank.map { " · 排名 \($0)" } ?? "")
            let summary = item.summary.map { "<p>\(escape($0))</p>" } ?? ""
            return "<article>\(rank)<h3>\(title)</h3><div class=\"item-meta\">\(meta)</div>\(summary)</article>"
        }.joined()
        return "<section class=\"panel\"><h2>\(escape(section.title))</h2>\(rows.isEmpty ? "<p>暂无内容。</p>" : rows)</section>"
    }

    private func renderAI(_ analysis: ReportAIAnalysis?) -> String {
        guard let analysis, analysis.hasContent || analysis.failureMessage != nil else { return "" }
        let body = [analysis.content ?? analysis.coreTrends, analysis.signals, analysis.sentimentControversy, analysis.rssInsights, analysis.recommendation].compactMap { $0 }.filter { !$0.isEmpty }.map { "<p>\(escape($0))</p>" }.joined()
        return "<section class=\"panel\"><h2>✨ AI 洞察</h2>\(body)\(analysis.failureMessage.map { "<p class=\"failure\">分析失败：\(escape($0))</p>" } ?? "")</section>"
    }

    private func renderNewItems(_ items: [ReportItemSnapshot]) -> String {
        guard !items.isEmpty else { return "" }
        return "<section class=\"panel\"><h2>🆕 新增热点</h2>\(items.map { "<p>· \(escape($0.title)) · \(escape($0.source))</p>" }.joined())</section>"
    }

    private func renderFailures(_ diagnostics: ReportDiagnostics?) -> String {
        guard let diagnostics, !diagnostics.failures.isEmpty else { return "" }
        return "<section class=\"panel\"><h2 class=\"failure\">⚠️ 采集异常</h2>\(diagnostics.failures.map { "<p class=\"failure\">\(escape($0.source))：\(escape($0.message))</p>" }.joined())</section>"
    }

    private func date(_ value: Date) -> String { value.formatted(date: .numeric, time: .shortened) }
    private func escape(_ value: String) -> String { value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;") }
}
