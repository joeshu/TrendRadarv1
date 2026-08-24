import SwiftUI
import UIKit

struct ReportOutputPreviewView: View {
    @EnvironmentObject private var reportStore: ReportStore
    @Environment(\.dismiss) private var dismiss
    let settings: AppSettings
    var reportID: UUID? = nil
    @State private var report: ReportDetail?
    @State private var selectedFormat = 0
    @State private var copied = false

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
                        if selectedFormat == 0 || selectedFormat == 2 {
                            VStack(alignment: .leading, spacing: 3) {
                                ForEach(Array(preview.components(separatedBy: .newlines).enumerated()), id: \.offset) { number, line in
                                    HStack(alignment: .top, spacing: 10) {
                                        Text("\(number + 1)").foregroundStyle(AppTheme.textTertiary).frame(width: 30, alignment: .trailing)
                                        Text(line.isEmpty ? " " : line).frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }.font(.system(.footnote, design: .monospaced)).textSelection(.enabled)
                        } else {
                            Text(preview).font(.system(.footnote, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                        }
                    }
                    HStack {
                        Text("\(preview.count) 字符 · \(preview.components(separatedBy: .newlines).count) 行")
                            .font(AppTheme.captionFont).foregroundStyle(AppTheme.textTertiary)
                        Spacer()
                        Button {
                            UIPasteboard.general.string = preview; copied = true
                        } label: { Label(copied ? "已复制" : "复制", systemImage: copied ? "checkmark" : "doc.on.doc") }
                            .buttonStyle(OutlineButtonStyle())
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
