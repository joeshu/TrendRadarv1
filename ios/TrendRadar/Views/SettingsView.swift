import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var newsStore: NewsStore
    @Environment(\.dismiss) private var dismiss
    @State private var keywordText = ""
    @State private var filterText = ""
    @State private var interestText = ""
    @State private var apiBase = ""
    @State private var apiKey = ""
    @State private var aiModel = ""
    private let keychain = KeychainStore()

    var body: some View {
        NavigationStack {
            Form {
                generalSection
                scheduleSection
                sourceSection
                filterSection
                aiSection
                displaySection
                notificationSection
            }
            .navigationTitle("配置中心")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .preferredColorScheme(.dark)
            .tint(AppTheme.cyan)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存", action: save) }
            }
            .onAppear(perform: load)
        }
    }

    private var generalSection: some View {
        Section("基础设置") {
            Picker("时区", selection: $settingsStore.settings.timezone) {
                Text("北京时间").tag("Asia/Shanghai")
                Text("纽约时间").tag("America/New_York")
                Text("伦敦时间").tag("Europe/London")
                Text("东京时间").tag("Asia/Tokyo")
            }
            Toggle("显示版本更新提示", isOn: $settingsStore.settings.showVersionUpdate)
            Picker("后台刷新间隔", selection: $settingsStore.settings.refreshInterval) {
                Text("30 分钟").tag(30.0)
                Text("1 小时").tag(60.0)
                Text("3 小时").tag(180.0)
                Text("6 小时").tag(360.0)
            }
            Text("iOS 后台执行时间由系统资源和使用习惯决定。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var scheduleSection: some View {
        Section("调度预设") {
            Toggle("启用调度系统", isOn: $settingsStore.settings.scheduleEnabled)
            Picker("运行模式", selection: $settingsStore.settings.schedulePreset) {
                Text("全天监控").tag("always_on")
                Text("早晚汇总").tag("morning_evening")
                Text("办公时间").tag("office_hours")
                Text("夜猫子模式").tag("night_owl")
                Text("自定义").tag("custom")
            }
            Text(scheduleDescription)
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var sourceSection: some View {
        Section("数据源") {
            Toggle("启用热榜平台", isOn: $settingsStore.settings.platformsEnabled)
            ForEach($settingsStore.settings.platformSources) { $source in
                Toggle(source.name, isOn: $source.isEnabled)
            }
            TextField("自定义热榜 API 地址", text: $settingsStore.settings.platformAPIURL)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            Toggle("启用 RSS 订阅", isOn: $settingsStore.settings.rssEnabled)
            Toggle("启用文章新鲜度过滤", isOn: $settingsStore.settings.rssFreshnessEnabled)
            Stepper("RSS 最大文章年龄：\(settingsStore.settings.rssMaxAgeDays) 天", value: $settingsStore.settings.rssMaxAgeDays, in: 0...30)
            ForEach($settingsStore.settings.customFeeds) { $feed in
                HStack {
                    Toggle(feed.name, isOn: $feed.isEnabled)
                    Spacer()
                    Text(feed.id).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var filterSection: some View {
        Section("关键词与筛选") {
            TextField("关注关键词，使用逗号分隔", text: $keywordText, axis: .vertical)
            TextField("全局过滤词，使用逗号分隔", text: $filterText, axis: .vertical)
            Picker("筛选方式", selection: $settingsStore.settings.ai.filterMethod) {
                Text("关键词匹配").tag("keyword")
                Text("AI 智能分类").tag("ai")
            }
            Picker("分组维度", selection: $settingsStore.settings.report.displayMode) {
                Text("按关键词").tag("keyword")
                Text("按来源平台").tag("platform")
            }
            Picker("报告模式", selection: $settingsStore.settings.report.mode) {
                Text("当前榜单").tag("current")
                Text("当日汇总").tag("daily")
                Text("增量监控").tag("incremental")
            }
            Toggle("按关键词定义顺序排序", isOn: $settingsStore.settings.report.sortByPositionFirst)
            Stepper("排名高亮阈值：\(settingsStore.settings.report.rankThreshold)", value: $settingsStore.settings.report.rankThreshold, in: 0...100)
            Stepper("每组最多显示：\(settingsStore.settings.report.maxNewsPerKeyword == 0 ? "不限" : "\(settingsStore.settings.report.maxNewsPerKeyword) 条")", value: $settingsStore.settings.report.maxNewsPerKeyword, in: 0...100)
        }
    }

    private var aiSection: some View {
        Section("AI 分析") {
            Toggle("启用 AI 分析", isOn: $settingsStore.settings.ai.enabled)
            TextField("API Base URL", text: $apiBase).textInputAutocapitalization(.never).autocorrectionDisabled()
            SecureField("API Key", text: $apiKey)
            TextField("模型名称", text: $aiModel).textInputAutocapitalization(.never).autocorrectionDisabled()
            TextField("AI 分析语言", text: $settingsStore.settings.ai.language)
            TextField("兴趣描述", text: $interestText, axis: .vertical).lineLimit(3...8)
            Stepper("请求超时：\(settingsStore.settings.ai.timeout) 秒", value: $settingsStore.settings.ai.timeout, in: 10...600, step: 10)
            Stepper("最大生成 Token：\(settingsStore.settings.ai.maxTokens == 0 ? "不限" : "\(settingsStore.settings.ai.maxTokens)")", value: $settingsStore.settings.ai.maxTokens, in: 0...20000, step: 500)
            Stepper("失败重试：\(settingsStore.settings.ai.retries) 次", value: $settingsStore.settings.ai.retries, in: 0...5)
            Text("API Key 保存在 iPhone Keychain 中，仅供本机使用。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var displaySection: some View {
        Section("推送内容") {
            Toggle("热榜区域", isOn: $settingsStore.settings.display.showHotlist)
            Toggle("新增热点区域", isOn: $settingsStore.settings.display.showNewItems)
            Toggle("RSS 区域", isOn: $settingsStore.settings.display.showRSS)
            Toggle("独立展示区", isOn: $settingsStore.settings.display.showStandalone)
            Toggle("AI 分析区域", isOn: $settingsStore.settings.display.showAIAnalysis)
            Stepper("独立展示最多：\(settingsStore.settings.display.standaloneMaxItems) 条", value: $settingsStore.settings.display.standaloneMaxItems, in: 0...100)
        }
    }

    private var notificationSection: some View {
        Section("通知与本地提醒") {
            Toggle("启用通知总开关", isOn: $settingsStore.settings.notification.enabled)
            Toggle("允许本地提醒", isOn: $settingsStore.settings.notification.localAlerts)
            Toggle("提醒声音", isOn: $settingsStore.settings.notification.soundEnabled)
            Text("手机端使用系统本地通知。飞书、钉钉、Telegram 等服务端渠道保留在原项目配置中。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var scheduleDescription: String {
        switch settingsStore.settings.schedulePreset {
        case "always_on": return "全天采集，有新增内容时及时提醒。"
        case "morning_evening": return "全天关注，晚间生成当日汇总。"
        case "office_hours": return "工作日到岗、午间、收工三段式推送。"
        case "night_owl": return "午后速览，深夜生成全天汇总。"
        default: return "使用自定义时间线配置。"
        }
    }

    private func load() {
        keywordText = settingsStore.settings.keywords.joined(separator: ", ")
        filterText = settingsStore.settings.globalFilterWords.joined(separator: ", ")
        interestText = settingsStore.settings.ai.interests
        apiBase = keychain.read("api-base")
        apiKey = keychain.read("api-key")
        aiModel = keychain.read("ai-model")
    }

    private func save() {
        settingsStore.settings.keywords = split(keywordText)
        settingsStore.settings.globalFilterWords = split(filterText)
        settingsStore.settings.ai.interests = interestText
        settingsStore.settings.enabledFeedIDs = Set(settingsStore.settings.customFeeds.filter(\.isEnabled).map(\.id))
        keychain.write(apiBase, for: "api-base")
        keychain.write(apiKey, for: "api-key")
        keychain.write(aiModel, for: "ai-model")
        newsStore.settings = settingsStore.settings
        dismiss()
    }

    private func split(_ value: String) -> [String] {
        value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}
