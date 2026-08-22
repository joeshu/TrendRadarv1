import SwiftUI

struct ReportOutputPreviewView: View {
    @EnvironmentObject private var reportStore: ReportStore
    @Environment(\.dismiss) private var dismiss
    let settings: AppSettings
    @State private var report: ReportDetail?
    @State private var selectedFormat = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("格式", selection: $selectedFormat) {
                Text("Markdown").tag(0)
                Text("HTML").tag(1)
                Text("JSON").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()
            ScrollView {
                Text(preview)
                    .font(.system(.footnote, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding()
            }
            .background(Color(.secondarySystemBackground))
        }
        .navigationTitle("报告输出预览")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if report == nil {
                ContentUnavailableView("暂无报告", systemImage: "doc.text", description: Text("先生成一份报告后再预览最终输出。"))
            }
        }
        .task {
            if let first = reportStore.reports.first {
                report = await reportStore.detail(id: first.id)
            }
        }
    }

    private var preview: String {
        guard let report else { return "暂无报告" }
        switch selectedFormat {
        case 1: return ReportHTMLFormatter().render(report)
        case 2:
            guard let data = try? JSONEncoder.webhook.encode(report) else { return "JSON 编码失败" }
            return String(decoding: data, as: UTF8.self)
        default: return ReportFormatter().render(report, format: .markdown)
        }
    }
}
