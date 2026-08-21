import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var newsStore: NewsStore
    @Environment(\.dismiss) private var dismiss
    @State private var keywordText = ""
    @State private var apiBase = ""
    @State private var apiKey = ""
    @State private var aiModel = ""
    private let keychain = KeychainStore()

    var body: some View {
        NavigationStack {
            Form {
                Section("关键词") {
                    TextField("输入关键词，使用逗号分隔", text: $keywordText)
                    Text("留空时显示全部新闻")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("RSS 来源") {
                    ForEach(newsStore.feeds) { feed in
                        Toggle(feed.name, isOn: Binding(
                            get: { settingsStore.settings.enabledFeedIDs.contains(feed.id) },
                            set: { enabled in
                                if enabled { settingsStore.settings.enabledFeedIDs.insert(feed.id) }
                                else { settingsStore.settings.enabledFeedIDs.remove(feed.id) }
                            }
                        ))
                    }
                }
                Section("后台刷新") {
                    Picker("刷新间隔", selection: $settingsStore.settings.refreshInterval) {
                        Text("30 分钟").tag(30.0)
                        Text("1 小时").tag(60.0)
                        Text("3 小时").tag(180.0)
                        Text("6 小时").tag(360.0)
                    }
                    Text("iOS 会根据系统资源和使用习惯决定实际执行时间。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("AI 配置") {
                    TextField("API Base URL", text: $apiBase)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("API Key", text: $apiKey)
                    TextField("模型名称", text: $aiModel)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("密钥保存在 iPhone Keychain 中，仅供本机使用。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .preferredColorScheme(.dark)
            .tint(Color.appCyan)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        settingsStore.settings.keywords = keywordText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                        keychain.write(apiBase, for: "api-base")
                        keychain.write(apiKey, for: "api-key")
                        keychain.write(aiModel, for: "ai-model")
                        newsStore.settings = settingsStore.settings
                        dismiss()
                    }
                }
            }
            .onAppear {
                keywordText = settingsStore.settings.keywords.joined(separator: ", ")
                apiBase = keychain.read("api-base")
                apiKey = keychain.read("api-key")
                aiModel = keychain.read("ai-model")
            }
        }
    }
}

private extension Color {
    static let appBackground = Color(red: 0.035, green: 0.055, blue: 0.10)
    static let appCyan = Color(red: 0.25, green: 0.90, blue: 0.82)
}
