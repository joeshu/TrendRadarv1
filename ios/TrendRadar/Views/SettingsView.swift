import SwiftUI
import UniformTypeIdentifiers

private enum SettingsCategory: String, CaseIterable, Identifiable, Hashable {
    case runtime
    case filtering
    case ai
    case display
    case notifications
    case storage
    case advanced
    case backup

    var id: String { rawValue }

    var title: String {
        switch self {
        case .runtime: return "运行与调度"
        case .filtering: return "筛选与报告"
        case .ai: return "AI"
        case .display: return "展示"
        case .notifications: return "通知"
        case .storage: return "存储"
        case .advanced: return "高级"
        case .backup: return "配置备份"
        }
    }

    var subtitle: String {
        switch self {
        case .runtime: return "时区、刷新和时间线"
        case .filtering: return "关键词、AI 筛选和报告"
        case .ai: return "模型、兴趣和翻译"
        case .display: return "首页区域与独立展示"
        case .notifications: return "本地提醒和通知渠道"
        case .storage: return "本地保留和远程存储"
        case .advanced: return "请求、代理和排序参数"
        case .backup: return "导入或分享配置"
        }
    }

    var icon: String {
        switch self {
        case .runtime: return "clock"
        case .filtering: return "line.3.horizontal.decrease.circle"
        case .ai: return "sparkles"
        case .display: return "rectangle.3.group"
        case .notifications: return "bell"
        case .storage: return "internaldrive"
        case .advanced: return "slider.horizontal.3"
        case .backup: return "arrow.triangle.2.circlepath"
        }
    }
}

private struct SettingsCategoryRow: View {
    let category: SettingsCategory

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.headline)
                .foregroundStyle(AppTheme.cyan)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(category.title)
                    .font(AppTheme.headlineFont)
                    .foregroundStyle(.white)
                Text(category.subtitle)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .padding(.vertical, 5)
    }
}

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
    @State private var channelSecrets: [String: String] = [:]
    @State private var showingFeedEditor = false
    @State private var editingFeed: ConfigFeed?
    @State private var showingSettingsImporter = false
    @State private var settingsMessage: String?
    @State private var isUpdatingInterestTags = false
    @State private var originalSettings: AppSettings?
    @State private var originalKeychainValues: [String: String] = [:]
    private let keychain = KeychainStore()

    var body: some View {
        NavigationStack {
            List {
                configurationOverview
                Section("设置") {
                    ForEach(SettingsCategory.allCases) { category in
                        NavigationLink(value: category) {
                            SettingsCategoryRow(category: category)
                        }
                    }
                }
            }
            .navigationTitle("配置中心")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .preferredColorScheme(.dark)
            .tint(AppTheme.cyan)
            .navigationDestination(for: SettingsCategory.self) { category in
                Form {
                    categoryContent(category)
                }
                .navigationTitle(category.title)
                .navigationBarTitleDisplayMode(.inline)
                .scrollContentBackground(.hidden)
                .background(AppTheme.background)
                .preferredColorScheme(.dark)
                .tint(AppTheme.cyan)
            }
            .onChange(of: settingsStore.settings) { _, newSettings in
                newsStore.settings = newSettings
                BackgroundRefreshService.schedule(after: newSettings.refreshInterval * 60)
            }
            .onChange(of: keywordText) { _, value in
                settingsStore.settings.keywords = split(value)
            }
            .onChange(of: filterText) { _, value in
                settingsStore.settings.globalFilterWords = split(value)
            }
            .onChange(of: interestText) { _, value in
                settingsStore.settings.ai.interests = value
            }
            .onChange(of: apiBase) { _, value in
                keychain.write(value, for: "api-base")
            }
            .onChange(of: apiKey) { _, value in
                keychain.write(value, for: "api-key")
            }
            .onChange(of: aiModel) { _, value in
                keychain.write(value, for: "ai-model")
            }
            .onChange(of: channelSecrets) { _, values in
                persistChannelSecrets(values)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        if let originalSettings {
                            settingsStore.settings = originalSettings
                            newsStore.settings = originalSettings
                        }
                        for (key, value) in originalKeychainValues {
                            keychain.write(value, for: key)
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) { Button("保存", action: save) }
            }
            .onAppear(perform: load)
            .sheet(isPresented: $showingFeedEditor) {
                FeedEditorView(feed: editingFeed) { feed in
                    if let index = settingsStore.settings.customFeeds.firstIndex(where: { $0.id == feed.id }) {
                        settingsStore.settings.customFeeds[index] = feed
                    } else {
                        settingsStore.settings.customFeeds.append(feed)
                    }
                    editingFeed = nil
                }
            }
            .fileImporter(isPresented: $showingSettingsImporter, allowedContentTypes: [.json]) { result in
                importSettings(result)
            }
            .alert("配置备份", isPresented: Binding(get: { settingsMessage != nil }, set: { if !$0 { settingsMessage = nil } })) {
                Button("确定", role: .cancel) { settingsMessage = nil }
            } message: {
                Text(settingsMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private func categoryContent(_ category: SettingsCategory) -> some View {
        switch category {
        case .runtime:
            generalSection
            scheduleSection
        case .filtering:
            filterSection
        case .ai:
            aiSection
            aiAnalysisSection
            aiTranslationSection
        case .display:
            displaySection
        case .notifications:
            notificationSection
        case .storage:
            storageSection
        case .advanced:
            advancedSection
        case .backup:
            backupSection
        }
    }

    private var configurationOverview: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("本地配置中心")
                    .font(AppTheme.headlineFont)
                    .foregroundStyle(.white)
            Text("常用配置按功能分组，高级请求参数单独收纳。所有数据默认保存在本机。")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textSecondary)
                HStack(spacing: 8) {
                    ConfigStatusPill(title: settingsStore.settings.platformsEnabled ? "热榜已启用" : "热榜已关闭", tint: settingsStore.settings.platformsEnabled ? AppTheme.green : AppTheme.textTertiary)
                    ConfigStatusPill(title: settingsStore.settings.rssEnabled ? "RSS 已启用" : "RSS 已关闭", tint: settingsStore.settings.rssEnabled ? AppTheme.cyan : AppTheme.textTertiary)
                    ConfigStatusPill(title: settingsStore.settings.ai.enabled ? "AI 已启用" : "AI 已关闭", tint: settingsStore.settings.ai.enabled ? AppTheme.pink : AppTheme.textTertiary)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("配置总览")
        }
    }

    private var generalSection: some View {
        Section("运行") {
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
        Section("时间线") {
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
            Text("对应远程 config.yaml 的 app、schedule 和 timeline 预设。iPhone 后台执行仍由系统决定实际唤醒时间。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var sourceSection: some View {
        Section("数据源") {
            Toggle("启用热榜平台", isOn: $settingsStore.settings.platformsEnabled)
            ForEach($settingsStore.settings.platformSources) { $source in
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("启用 \(source.name)", isOn: $source.isEnabled)
                    TextField("平台名称", text: $source.name)
                    TextField("安全校验域名", text: $source.expectedDomain)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
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
                .contentShape(Rectangle())
                .onTapGesture {
                    editingFeed = feed
                    showingFeedEditor = true
                }
            }
            Button("添加 RSS 源") {
                editingFeed = nil
                showingFeedEditor = true
            }
            Text("点击已有 RSS 源可编辑名称、地址、启用状态和单源新鲜度覆盖。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var filterSection: some View {
        Section("筛选与报告") {
            TextField("关键词：普通词、+必须词、!过滤词", text: $keywordText, axis: .vertical)
            TextField("全局过滤词，使用逗号分隔", text: $filterText, axis: .vertical)
            Text("示例：AI, +发布, !广告。必须词全部命中，普通词命中任意一个，过滤词命中后排除。")
                .font(.caption)
                .foregroundStyle(.secondary)
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
        Section("模型与智能筛选") {
            Toggle("启用 AI 分析", isOn: $settingsStore.settings.ai.enabled)
            TextField("API Base URL", text: $apiBase).textInputAutocapitalization(.never).autocorrectionDisabled()
            SecureField("API Key", text: $apiKey)
            TextField("模型名称", text: $aiModel).textInputAutocapitalization(.never).autocorrectionDisabled()
            TextField("AI 分析语言", text: $settingsStore.settings.ai.language)
            TextField("兴趣描述", text: $interestText, axis: .vertical).lineLimit(3...8)
            Button(isUpdatingInterestTags ? "正在更新兴趣标签..." : "根据兴趣描述更新标签") {
                updateInterestTags()
            }
            .disabled(isUpdatingInterestTags || interestText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            if !settingsStore.settings.ai.interestTags.isEmpty {
                Text("当前标签：" + settingsStore.settings.ai.interestTags.map(\.tag).joined(separator: "、"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Toggle("按兴趣顺序排序", isOn: $settingsStore.settings.ai.prioritySortEnabled)
            Stepper("AI 筛选批量：\(settingsStore.settings.ai.batchSize) 条", value: $settingsStore.settings.ai.batchSize, in: 1...1000, step: 10)
            Stepper("AI 筛选批次间隔：\(settingsStore.settings.ai.batchInterval) 秒", value: $settingsStore.settings.ai.batchInterval, in: 0...60)
            Stepper("最低筛选分数：\(settingsStore.settings.ai.minimumScore, specifier: "%.2f")", value: $settingsStore.settings.ai.minimumScore, in: 0...1, step: 0.05)
            Stepper("重分类阈值：\(settingsStore.settings.ai.reclassifyThreshold, specifier: "%.2f")", value: $settingsStore.settings.ai.reclassifyThreshold, in: 0...1, step: 0.05)
            Stepper("Temperature：\(settingsStore.settings.ai.temperature, specifier: "%.1f")", value: $settingsStore.settings.ai.temperature, in: 0...2, step: 0.1)
            TextField("备用模型，使用逗号分隔", text: Binding(
                get: { settingsStore.settings.ai.fallbackModels.joined(separator: ", ") },
                set: { settingsStore.settings.ai.fallbackModels = split($0) }
            ))
            DisclosureGroup("高级 Prompt 文件") {
                TextField("AI 筛选提示词文件", text: $settingsStore.settings.ai.filterPromptFile)
                TextField("AI 标签提取提示词文件", text: $settingsStore.settings.ai.extractPromptFile)
                TextField("AI 标签更新提示词文件", text: $settingsStore.settings.ai.updateTagsPromptFile)
            }
            Stepper("请求超时：\(settingsStore.settings.ai.timeout) 秒", value: $settingsStore.settings.ai.timeout, in: 10...600, step: 10)
            Stepper("最大生成 Token：\(settingsStore.settings.ai.maxTokens == 0 ? "不限" : "\(settingsStore.settings.ai.maxTokens)")", value: $settingsStore.settings.ai.maxTokens, in: 0...20000, step: 500)
            Stepper("失败重试：\(settingsStore.settings.ai.retries) 次", value: $settingsStore.settings.ai.retries, in: 0...5)
            Text("API Key 保存在 iPhone Keychain 中，仅供本机使用。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var displaySection: some View {
        Section("展示区域") {
            Toggle("热榜区域", isOn: $settingsStore.settings.display.showHotlist)
            Toggle("新增热点区域", isOn: $settingsStore.settings.display.showNewItems)
            Toggle("RSS 区域", isOn: $settingsStore.settings.display.showRSS)
            Toggle("独立展示区", isOn: $settingsStore.settings.display.showStandalone)
            Toggle("AI 分析区域", isOn: $settingsStore.settings.display.showAIAnalysis)
            DisclosureGroup("独立展示区高级设置") {
                TextField("区域顺序，使用逗号分隔", text: Binding(
                    get: { settingsStore.settings.display.regionOrder.joined(separator: ", ") },
                    set: { settingsStore.settings.display.regionOrder = split($0) }
                ))
                TextField("独立展示平台 ID，使用逗号分隔", text: Binding(
                    get: { settingsStore.settings.display.standalonePlatforms.joined(separator: ", ") },
                    set: { settingsStore.settings.display.standalonePlatforms = split($0) }
                ))
                TextField("独立展示 RSS ID，使用逗号分隔", text: Binding(
                    get: { settingsStore.settings.display.standaloneRSSFeeds.joined(separator: ", ") },
                    set: { settingsStore.settings.display.standaloneRSSFeeds = split($0) }
                ))
                Stepper("独立展示最多：\(settingsStore.settings.display.standaloneMaxItems) 条", value: $settingsStore.settings.display.standaloneMaxItems, in: 0...100)
            }
        }
    }

    private var aiAnalysisSection: some View {
        Section("结构化分析") {
            Toggle("启用 AI 分析", isOn: $settingsStore.settings.aiAnalysis.enabled)
            TextField("分析语言", text: $settingsStore.settings.aiAnalysis.language)
            Picker("分析模式", selection: $settingsStore.settings.aiAnalysis.mode) {
                Text("跟随报告模式").tag("follow_report")
                Text("当前榜单").tag("current")
                Text("当日汇总").tag("daily")
                Text("增量内容").tag("incremental")
            }
            Stepper("最多分析新闻：\(settingsStore.settings.aiAnalysis.maxNewsForAnalysis) 条", value: $settingsStore.settings.aiAnalysis.maxNewsForAnalysis, in: 0...1000, step: 10)
            Toggle("包含 RSS 内容", isOn: $settingsStore.settings.aiAnalysis.includeRSS)
            Toggle("包含独立展示区", isOn: $settingsStore.settings.aiAnalysis.includeStandalone)
            Toggle("包含排名时间线", isOn: $settingsStore.settings.aiAnalysis.includeRankTimeline)
            TextField("提示词文件", text: $settingsStore.settings.aiAnalysis.promptFile)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
        }
    }

    private var aiTranslationSection: some View {
        Section("翻译") {
            Toggle("启用标题翻译", isOn: $settingsStore.settings.aiTranslation.enabled)
            TextField("目标语言", text: $settingsStore.settings.aiTranslation.language)
            TextField("提示词文件", text: $settingsStore.settings.aiTranslation.promptFile)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            Stepper("每批翻译：\(settingsStore.settings.aiTranslation.batchSize) 条", value: $settingsStore.settings.aiTranslation.batchSize, in: 1...1000, step: 10)
            Stepper("批次间隔：\(settingsStore.settings.aiTranslation.batchInterval) 秒", value: $settingsStore.settings.aiTranslation.batchInterval, in: 0...60)
            Toggle("翻译热榜标题", isOn: $settingsStore.settings.aiTranslation.translateHotlist)
            Toggle("翻译 RSS 标题", isOn: $settingsStore.settings.aiTranslation.translateRSS)
            Toggle("翻译独立展示标题", isOn: $settingsStore.settings.aiTranslation.translateStandalone)
        }
    }

    private var notificationSection: some View {
        Section("本地提醒") {
            Toggle("启用通知总开关", isOn: $settingsStore.settings.notification.enabled)
            Toggle("允许本地提醒", isOn: $settingsStore.settings.notification.localAlerts)
            Toggle("提醒声音", isOn: $settingsStore.settings.notification.soundEnabled)
            Text("服务端通知渠道")
                .font(.subheadline).foregroundStyle(AppTheme.cyan)
            SecureField("飞书 Webhook", text: channelBinding("feishu"))
            SecureField("钉钉 Webhook", text: channelBinding("dingtalk"))
            SecureField("企业微信 Webhook", text: channelBinding("wework"))
            TextField("企业微信消息类型", text: $settingsStore.settings.notification.channels.weworkMessageType)
            SecureField("Telegram Bot Token", text: channelBinding("telegram-token"))
            TextField("Telegram Chat ID", text: channelBinding("telegram-chat"))
            TextField("邮件发件人", text: $settingsStore.settings.notification.channels.emailFrom)
            SecureField("邮件密码或授权码", text: channelBinding("email-password"))
            TextField("邮件收件人（逗号分隔）", text: $settingsStore.settings.notification.channels.emailTo)
            TextField("SMTP 服务器", text: $settingsStore.settings.notification.channels.emailSMTPServer)
            TextField("SMTP 端口", text: $settingsStore.settings.notification.channels.emailSMTPPort)
            TextField("ntfy 服务地址", text: $settingsStore.settings.notification.channels.ntfyServerURL)
            TextField("ntfy 主题", text: $settingsStore.settings.notification.channels.ntfyTopic)
            SecureField("ntfy Token", text: channelBinding("ntfy-token"))
            SecureField("Bark URL", text: channelBinding("bark"))
            SecureField("Slack Webhook", text: channelBinding("slack"))
            SecureField("通用 Webhook", text: channelBinding("generic"))
            TextField("通用 JSON Payload 模板", text: $settingsStore.settings.notification.channels.genericPayloadTemplate, axis: .vertical)
            Text("手机端使用系统本地通知。飞书、钉钉、Telegram 等服务端渠道保留在原项目配置中。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var storageSection: some View {
        Section("本地与远程存储") {
            Picker("存储后端", selection: $settingsStore.settings.storage.backend) {
                Text("自动选择").tag("auto")
                Text("本地").tag("local")
                Text("远程 S3").tag("remote")
            }
            Toggle("SQLite 主存储", isOn: $settingsStore.settings.storage.sqliteEnabled)
            Toggle("生成 TXT 快照", isOn: $settingsStore.settings.storage.txtEnabled)
            Toggle("生成 HTML 报告", isOn: $settingsStore.settings.storage.htmlEnabled)
            TextField("本地数据目录", text: $settingsStore.settings.storage.localDataDirectory)
            Stepper("本地保留天数：\(settingsStore.settings.storage.localRetentionDays == 0 ? "永久" : "\(settingsStore.settings.storage.localRetentionDays)")", value: $settingsStore.settings.storage.localRetentionDays, in: 0...3650)
            Stepper("远程保留天数：\(settingsStore.settings.storage.remoteRetentionDays == 0 ? "永久" : "\(settingsStore.settings.storage.remoteRetentionDays)")", value: $settingsStore.settings.storage.remoteRetentionDays, in: 0...3650)
            TextField("S3 Endpoint URL", text: $settingsStore.settings.storage.remoteEndpointURL)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            TextField("S3 Bucket", text: $settingsStore.settings.storage.remoteBucketName)
            SecureField("S3 Access Key ID", text: channelBinding("s3-access"))
            SecureField("S3 Secret Access Key", text: channelBinding("s3-secret"))
            TextField("S3 Region", text: $settingsStore.settings.storage.remoteRegion)
            Toggle("启动时拉取远程数据", isOn: $settingsStore.settings.storage.pullEnabled)
            Stepper("拉取最近：\(settingsStore.settings.storage.pullDays) 天", value: $settingsStore.settings.storage.pullDays, in: 1...365)
            Text("S3/R2、账号同步和服务端推送属于可选远程能力。纯本地模式保持独立运行。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var advancedSection: some View {
        Section("高级参数") {
            Toggle("调试模式", isOn: $settingsStore.settings.advanced.debug)
            TextField("版本检查地址", text: $settingsStore.settings.advanced.versionCheckURL)
            TextField("MCP 版本检查地址", text: $settingsStore.settings.advanced.mcpVersionCheckURL)
            TextField("配置版本检查地址", text: $settingsStore.settings.advanced.configsVersionCheckURL)
            Stepper("热榜请求间隔：\(settingsStore.settings.advanced.crawler.requestIntervalMilliseconds) ms", value: $settingsStore.settings.advanced.crawler.requestIntervalMilliseconds, in: 0...60000, step: 100)
            Toggle("热榜使用代理", isOn: $settingsStore.settings.advanced.crawler.useProxy)
            TextField("默认代理", text: $settingsStore.settings.advanced.crawler.defaultProxy)
            Stepper("RSS 请求间隔：\(settingsStore.settings.advanced.rss.requestIntervalMilliseconds) ms", value: $settingsStore.settings.advanced.rss.requestIntervalMilliseconds, in: 0...60000, step: 100)
            Stepper("RSS 超时：\(settingsStore.settings.advanced.rss.timeout) 秒", value: $settingsStore.settings.advanced.rss.timeout, in: 1...300)
            Toggle("RSS 使用代理", isOn: $settingsStore.settings.advanced.rss.useProxy)
            TextField("RSS 专属代理", text: $settingsStore.settings.advanced.rss.proxyURL)
            Stepper("账号渠道上限：\(settingsStore.settings.advanced.maxAccountsPerChannel)", value: $settingsStore.settings.advanced.maxAccountsPerChannel, in: 1...20)
            Stepper("默认消息批次：\(settingsStore.settings.advanced.defaultBatchSize) 字节", value: $settingsStore.settings.advanced.defaultBatchSize, in: 500...50000, step: 500)
            Stepper("钉钉消息批次：\(settingsStore.settings.advanced.dingtalkBatchSize) 字节", value: $settingsStore.settings.advanced.dingtalkBatchSize, in: 500...50000, step: 500)
            Stepper("飞书消息批次：\(settingsStore.settings.advanced.feishuBatchSize) 字节", value: $settingsStore.settings.advanced.feishuBatchSize, in: 500...50000, step: 500)
            Stepper("Bark 消息批次：\(settingsStore.settings.advanced.barkBatchSize) 字节", value: $settingsStore.settings.advanced.barkBatchSize, in: 500...50000, step: 500)
            Stepper("Slack 消息批次：\(settingsStore.settings.advanced.slackBatchSize) 字节", value: $settingsStore.settings.advanced.slackBatchSize, in: 500...50000, step: 500)
            Text("排序权重")
            Slider(value: $settingsStore.settings.advanced.rankWeight, in: 0...1) { Text("排名") }
            Slider(value: $settingsStore.settings.advanced.frequencyWeight, in: 0...1) { Text("频次") }
            Slider(value: $settingsStore.settings.advanced.hotnessWeight, in: 0...1) { Text("热度") }
            Text(String(format: "排名 %.2f / 频次 %.2f / 热度 %.2f", settingsStore.settings.advanced.rankWeight, settingsStore.settings.advanced.frequencyWeight, settingsStore.settings.advanced.hotnessWeight))
                .font(.caption).foregroundStyle(.secondary)
            Stepper("批次发送间隔：\(settingsStore.settings.advanced.batchSendInterval) 秒", value: $settingsStore.settings.advanced.batchSendInterval, in: 0...60)
            TextField("飞书消息分隔符", text: $settingsStore.settings.advanced.feishuMessageSeparator)
        }
    }

    private var backupSection: some View {
        Section("配置文件") {
            ShareLink(item: settingsJSON) {
                Label("分享配置 JSON", systemImage: "square.and.arrow.up")
            }
            Button {
                showingSettingsImporter = true
            } label: {
                Label("导入配置 JSON", systemImage: "square.and.arrow.down")
            }
            Text("配置仅保存在本机。API Key 和通知密钥不会写入 JSON，仍由 Keychain 单独管理。")
                .font(.caption)
                .foregroundStyle(.secondary)
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
        originalSettings = settingsStore.settings
        keywordText = settingsStore.settings.keywords.joined(separator: ", ")
        filterText = settingsStore.settings.globalFilterWords.joined(separator: ", ")
        interestText = settingsStore.settings.ai.interests
        apiBase = keychain.read("api-base")
        apiKey = keychain.read("api-key")
        aiModel = keychain.read("ai-model")
        channelSecrets = [
            "feishu": keychain.read("notify-feishu"),
            "dingtalk": keychain.read("notify-dingtalk"),
            "wework": keychain.read("notify-wework"),
            "telegram-token": keychain.read("notify-telegram-token"),
            "telegram-chat": keychain.read("notify-telegram-chat"),
            "email-password": keychain.read("notify-email-password"),
            "ntfy-token": keychain.read("notify-ntfy-token"),
            "bark": keychain.read("notify-bark"),
            "slack": keychain.read("notify-slack"),
            "generic": keychain.read("notify-generic"),
            "s3-access": keychain.read("storage-s3-access"),
            "s3-secret": keychain.read("storage-s3-secret")
        ]
        originalKeychainValues = [
            "api-base": apiBase,
            "api-key": apiKey,
            "ai-model": aiModel,
            "notify-feishu": channelSecrets["feishu"] ?? "",
            "notify-dingtalk": channelSecrets["dingtalk"] ?? "",
            "notify-wework": channelSecrets["wework"] ?? "",
            "notify-telegram-token": channelSecrets["telegram-token"] ?? "",
            "notify-telegram-chat": channelSecrets["telegram-chat"] ?? "",
            "notify-email-password": channelSecrets["email-password"] ?? "",
            "notify-ntfy-token": channelSecrets["ntfy-token"] ?? "",
            "notify-bark": channelSecrets["bark"] ?? "",
            "notify-slack": channelSecrets["slack"] ?? "",
            "notify-generic": channelSecrets["generic"] ?? "",
            "storage-s3-access": channelSecrets["s3-access"] ?? "",
            "storage-s3-secret": channelSecrets["s3-secret"] ?? ""
        ]
    }

    private func save() {
        settingsStore.settings.keywords = split(keywordText)
        settingsStore.settings.globalFilterWords = split(filterText)
        settingsStore.settings.ai.interests = interestText
        settingsStore.settings.enabledFeedIDs = Set(settingsStore.settings.customFeeds.filter(\.isEnabled).map(\.id))
        keychain.write(apiBase, for: "api-base")
        keychain.write(apiKey, for: "api-key")
        keychain.write(aiModel, for: "ai-model")
        let secretKeys = [
            "feishu": "notify-feishu", "dingtalk": "notify-dingtalk", "wework": "notify-wework",
            "telegram-token": "notify-telegram-token", "telegram-chat": "notify-telegram-chat", "email-password": "notify-email-password",
            "ntfy-token": "notify-ntfy", "bark": "notify-bark", "slack": "notify-slack",
            "generic": "notify-generic", "s3-access": "storage-s3-access", "s3-secret": "storage-s3-secret"
        ]
        for (field, key) in secretKeys { keychain.write(channelSecrets[field] ?? "", for: key) }
        newsStore.settings = settingsStore.settings
        originalSettings = settingsStore.settings
        BackgroundRefreshService.schedule(after: settingsStore.settings.refreshInterval * 60)
        dismiss()
    }

    private func updateInterestTags() {
        isUpdatingInterestTags = true
        var pendingSettings = settingsStore.settings
        pendingSettings.ai.interests = interestText
        Task {
            do {
                let update = try await AIService().updateInterestTags(settings: pendingSettings)
                let kept = update.keep.enumerated().map { AIInterestTag(id: $0.offset + 1, tag: $0.element.tag, description: $0.element.description) }
                let additions = update.add.enumerated().map { AIInterestTag(id: kept.count + $0.offset + 1, tag: $0.element.tag, description: $0.element.description) }
                pendingSettings.ai.interestTags = Array((kept + additions).prefix(20))
                await MainActor.run {
                    settingsStore.settings = pendingSettings
                    newsStore.settings = pendingSettings
                    settingsMessage = "兴趣标签已更新"
                    isUpdatingInterestTags = false
                }
            } catch {
                await MainActor.run {
                    settingsMessage = "兴趣标签更新失败：\(error.localizedDescription)"
                    isUpdatingInterestTags = false
                }
            }
        }
    }

    private var settingsJSON: String {
        guard let data = try? JSONEncoder().encode(settingsStore.settings),
              let value = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return value
    }

    private func importSettings(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessGranted = url.startAccessingSecurityScopedResource()
            defer {
                if accessGranted { url.stopAccessingSecurityScopedResource() }
            }
            let data = try Data(contentsOf: url)
            settingsStore.settings = try JSONDecoder().decode(AppSettings.self, from: data)
            load()
            newsStore.settings = settingsStore.settings
            settingsMessage = "配置已导入，敏感凭据继续使用当前 Keychain 内容。"
        } catch {
            settingsMessage = "配置导入失败：\(error.localizedDescription)"
        }
    }

    private func channelBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { channelSecrets[key] ?? "" },
            set: { channelSecrets[key] = $0 }
        )
    }

    private func persistChannelSecrets(_ values: [String: String]) {
        let secretKeys = [
            "feishu": "notify-feishu", "dingtalk": "notify-dingtalk", "wework": "notify-wework",
            "telegram-token": "notify-telegram-token", "telegram-chat": "notify-telegram-chat", "email-password": "notify-email-password",
            "ntfy-token": "notify-ntfy-token", "bark": "notify-bark", "slack": "notify-slack",
            "generic": "notify-generic", "s3-access": "storage-s3-access", "s3-secret": "storage-s3-secret"
        ]
        for (field, key) in secretKeys { keychain.write(values[field] ?? "", for: key) }
    }

    private func split(_ value: String) -> [String] {
        value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}

private struct ConfigStatusPill: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(AppTheme.captionFont)
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
    }
}

struct FeedEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var id: String
    @State private var name: String
    @State private var url: String
    @State private var isEnabled: Bool
    @State private var maxAgeDays: Int
    private let onSave: (ConfigFeed) -> Void

    init(feed: ConfigFeed?, onSave: @escaping (ConfigFeed) -> Void) {
        _id = State(initialValue: feed?.id ?? "custom-feed")
        _name = State(initialValue: feed?.name ?? "自定义源")
        _url = State(initialValue: feed?.url ?? "https://example.com/feed.xml")
        _isEnabled = State(initialValue: feed?.isEnabled ?? true)
        _maxAgeDays = State(initialValue: feed?.maxAgeDays ?? 0)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("RSS 基本信息") {
                    TextField("唯一 ID", text: $id)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("显示名称", text: $name)
                    TextField("订阅地址", text: $url)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Toggle("启用此源", isOn: $isEnabled)
                }
                Section("新鲜度") {
                    Stepper("单源最大年龄：\(maxAgeDays == 0 ? "跟随全局" : "\(maxAgeDays) 天")", value: $maxAgeDays, in: 0...30)
                }
            }
            .navigationTitle("编辑 RSS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let normalizedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
                        let normalizedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !normalizedID.isEmpty, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                              URL(string: normalizedURL) != nil else { return }
                        onSave(ConfigFeed(id: normalizedID, name: name, url: normalizedURL, isEnabled: isEnabled, maxAgeDays: maxAgeDays))
                        dismiss()
                    }
                }
            }
            .preferredColorScheme(.dark)
            .tint(AppTheme.cyan)
        }
    }
}
