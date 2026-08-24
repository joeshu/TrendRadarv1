import SwiftUI

struct ReportOutputPreviewView: View {
    @EnvironmentObject private var reportStore: ReportStore
    @Environment(\.dismiss) private var dismiss
    let settings: AppSettings
    var reportID: UUID? = nil
    @State private var report: ReportDetail?
    @State private var selectedFormat = 0

    var body: some View {
        ZStack {
            IntelligenceScreenBackground()
            VStack(spacing: 14) {
                Picker("格式", selection: $selectedFormat) {
                    Text("Markdown").tag(0)
                    Text("HTML").tag(1)
                    Text("JSON").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("输出内容", systemImage: selectedFormat == 0 ? "doc.text" : selectedFormat == 1 ? "globe" : "curlybraces")
                            .font(AppTheme.cardTitleFont)
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Text(["Markdown", "HTML", "JSON"][selectedFormat])
                            .font(AppTheme.captionFont)
                            .foregroundStyle(AppTheme.brandCyan)
                    }
                    ScrollView {
                        Text(preview)
                            .font(.system(.footnote, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .intelligenceCard(tint: AppTheme.brandIndigo, cornerRadius: 20)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .navigationTitle("报告输出预览")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: preview) {
                    ToolbarIconLabel(systemName: "square.and.arrow.up", label: "分享当前预览")
                }
                .disabled(report == nil)
            }
        }
        .overlay {
            if report == nil {
                ContentUnavailableView("暂无报告", systemImage: "doc.text", description: Text("先生成一份报告后再预览最终输出。"))
            }
        }
        .task {
            if let targetID = reportID ?? reportStore.reports.first?.id {
                report = await reportStore.detail(id: targetID)
            }
        }
    }

    private var preview: String {
        guard let report else { return "暂无报告" }
        switch selectedFormat {
        case 1: return ReportHTMLFormatter().render(report)
        case 2:
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            guard let data = try? encoder.encode(report) else { return "JSON 编码失败" }
            return String(decoding: data, as: UTF8.self)
        default: return ReportFormatter().render(report, format: .markdown)
        }
    }
}
