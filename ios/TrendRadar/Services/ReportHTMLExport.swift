import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct ReportHTMLExport: Transferable {
    let report: ReportDetail

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .html) { export in
            Data(ReportHTMLFormatter().render(export.report).utf8)
        }
        .suggestedFileName { export in
            "TrendRadar-\(export.report.id.uuidString).html"
        }
    }
}

struct ReportHTMLFormatter {
    func render(_ report: ReportDetail) -> String {
        let analysis = report.aiAnalysis?.hasContent == true
            ? "<section><h2>AI 热点分析</h2><p>\(escape(report.aiAnalysis?.content ?? ""))</p></section>"
            : ""
        let sections = report.sections.map { section in
            let rows = section.items.map { item in
                let rank = item.rank.map { "<span class=\"rank\">#\($0)</span>" } ?? ""
                let summary = item.summary.map { "<p>\(escape($0))</p>" } ?? ""
                let title = item.url.map { "<a href=\"\(escape($0.absoluteString))\">\(escape(item.title))</a>" } ?? escape(item.title)
                return "<article>\(rank)<h3>\(title)</h3><small>\(escape(item.source))</small>\(summary)</article>"
            }.joined()
            return "<section><h2>\(escape(section.title))</h2>\(rows)</section>"
        }.joined()
        return """
        <!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>\(escape(report.title))</title><style>
        :root{color-scheme:light dark}body{margin:0;background:#f4f5f7;color:#172033;font:15px/1.6 -apple-system,BlinkMacSystemFont,sans-serif}.page{max-width:720px;margin:auto;background:#fff;min-height:100vh}.hero{padding:34px 24px;color:#fff;background:linear-gradient(135deg,#312e81,#7c3aed)}main{padding:20px}section{margin:0 0 22px}article{position:relative;padding:14px 0;border-bottom:1px solid #e5e7eb}h1{font-size:25px}h2{font-size:19px;color:#4f46e5}h3{margin:2px 42px 3px 0;font-size:16px}a{color:#4338ca;text-decoration:none}.rank{float:right;color:#e11d48;font-weight:700}small{color:#6b7280}p{white-space:pre-wrap}@media(prefers-color-scheme:dark){body,.page{background:#10131a;color:#eef2ff}article{border-color:#293043}h2,a{color:#8be9fd}}
        </style></head><body><div class="page"><header class="hero"><h1>\(escape(report.title))</h1><div>\(report.statistics.newsCount) 条情报 · \(report.statistics.sourceCount) 个来源</div></header><main>\(analysis)\(sections)</main></div></body></html>
        """
    }

    private func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
