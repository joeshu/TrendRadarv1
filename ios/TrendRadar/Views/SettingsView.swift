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
    case health

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
        case .health: return "系统健康"
        }
    }

    var subtitle: String {
        switch self {
        case .runtime: return "时区、刷新和时间线"
        case .filtering: return "关键词、AI 筛选和报告"
        case .ai: return "模型、兴趣和翻译"
        case .display: return "主题、字体、界面密度与展示区域"
        case .notifications: return "本地提醒和通知渠道"
        case .storage: return "本地保留和远程存储"
        case .advanced: return "请求、代理和排序参数"
        case .backup: return "导入或分享配置"
        case .health: return "采集流水线、来源与恢复日志"
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
        case .health: return "heart.text.square"
        }
    }
}

private struct SettingsCategoryRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let category: SettingsCategory

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: category.icon)
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(AppTheme.brandCyan)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(category.title)
                    .font(AppTheme.cardTitleFont)
                    .foregroundStyle(AppTheme.textPrimary)
                Text(category.subtitle)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 76)
        .contentShape(Rectangle())
    }
}

private struct SettingsCategoriesSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("设置")
                .font(AppTheme.sectionTitleFont)
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            VStack(spacing: 0) {
                ForEach(Array(SettingsCategory.allCases.enumerated()), id: \.element.id) { index, category in
                    NavigationLink(value: category) {
                        SettingsCategoryRow(category: category)
                    }
                    .buttonStyle(.plain)
                    if index < SettingsCategory.allCases.count - 1 {
                        Divider().padding(.leading, 62).overlay(AppTheme.cardBorder)
                    }
                }
            }
            .intelligenceCard(tint: AppTheme.brandIndigo, cornerRadius: 22)
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 18)
    }
}

private struct SettingsOverviewSection: View {
    let platformsEnabled: Bool
    let rssEnabled: Bool
    let aiEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(AppTheme.brandCyan)
                    Image(systemName: "person.fill")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 58, height: 58)
                VStack(alignment: .leading, spacing: 4) {
                    Text("TrendRadar 用户")
                        .font(AppTheme.sectionTitleFont)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("本地版 · 运行状态正常")
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .padding(18)
            Divider().overlay(AppTheme.cardBorder)
            HStack(spacing: 0) {
                SettingsRuntimeStatus(title: "运行中", detail: "采集与分析已启动", tint: AppTheme.green)
                Divider().frame(height: 42).overlay(AppTheme.cardBorder)
                SettingsRuntimeStatus(title: "信息源", detail: "\(platformsEnabled && rssEnabled ? "热榜与 RSS" : "部分关闭")", tint: AppTheme.brandCyan)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .intelligenceCard(tint: AppTheme.brandCyan, cornerRadius: 22)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }
}

private struct SettingsRuntimeStatus: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    let detail: String
    let tint: Color
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(tint).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AppTheme.headlineFont).foregroundStyle(AppTheme.textPrimary)
                Text(detail).font(AppTheme.captionFont).foregroundStyle(AppTheme.textSecondary).lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var newsStore: NewsStore
    @EnvironmentObject private var hotNewsStore: HotNewsStore
    @EnvironmentObject private var reportStore: ReportStore
    @Environment(\.dismiss) private var dismiss
    @State private var keywordText = ""
    @State private var filterText = ""
    @State private var keywordPreviewText = ""
    @State private var interestText = ""
    @State private var apiBase = ""
    @State private var apiKey = ""
    @State private var aiModel = ""
    @State private var channelSecrets: [String: String] = [:]
    @State private var showingFeedEditor = false
    @State private var editingFeed: ConfigFeed?
    @State private var showingSettingsImporter = false
    @State private var settingsMessage: String?
    @State private var showingSettingsMessage = false
    @State private var isSaveConfirmation = false
    @State private var isResettingData = false
    @State private var isUpdatingInterestTags = false
    @State private var isTestingAI = false
    @State private var aiAvailabilityMessage: String?
    @State private var isTestingWebhook = false
    @State private var showingClearCacheConfirmation = false
    @State private var showingResetConfirmation = false
    @State private var originalSettings: AppSettings?
    @State private var originalKeychainValues: [String: String] = [:]
    private let keychain = KeychainStore()

    var body: some View {
        settingsInteractiveContent
    }

    private var settingsInteractiveContent: AnyView {
        var view = AnyView(settingsNavigation)
        view = AnyView(view.onChange(of: settingsStore.settings) { _, newSettings in
                newsStore.settings = newSettings
                BackgroundRefreshService.schedule(after: newSettings.refreshInterval * 60, enabled: newSettings.scheduleEnabled)
            })
        view = AnyView(view.onChange(of: keywordText) { _, value in
                settingsStore.settings.keywords = split(value)
            })
        view = AnyView(view.onChange(of: filterText) { _, value in
                settingsStore.settings.globalFilterWords = split(value)
            })
        view = AnyView(view.onChange(of: interestText) { _, value in
                settingsStore.settings.ai.interests = value
            })
        view = AnyView(view.onChange(of: apiBase) { _, value in
                keychain.write(value, for: "api-base")
            })
        view = AnyView(view.onChange(of: apiKey) { _, value in
                keychain.write(value, for: "api-key")
            })
        view = AnyView(view.onChange(of: aiModel) { _, value in
                keychain.write(value, for: "ai-model")
            })
        view = AnyView(view.onChange(of: channelSecrets) { _, values in
                persistChannelSecrets(values)
            })
        view = AnyView(view.onChange(of: settingsMessage) { _, value in
                if value != nil {
                    showingSettingsMessage = true
                }
            })
        view = AnyView(view.toolbar {
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
            })
        view = AnyView(view.onAppear(perform: load))
        view = AnyView(view.sheet(isPresented: $showingFeedEditor) {
                FeedEditorView(feed: editingFeed, onSave: { feed in
                    if let index = settingsStore.settings.customFeeds.firstIndex(where: { $0.id == feed.id }) {
                        settingsStore.settings.customFeeds[index] = feed
                    } else {
                        settingsStore.settings.customFeeds.append(feed)
                    }
                    editingFeed = nil
                }, onDelete: editingFeed.map { target in
                    { settingsStore.settings.customFeeds.removeAll { $0.id == target.id }; editingFeed = nil }
                })
            })
        view = AnyView(view.fileImporter(isPresented: $showingSettingsImporter, allowedContentTypes: [.json]) { result in
                importSettings(result)
            })
        view = AnyView(view.alert("操作结果", isPresented: $showingSettingsMessage) {
                Button("确定", role: .cancel) {
                    settingsMessage = nil
                    if isSaveConfirmation {
                        isSaveConfirmation = false
                        dismiss()
                    }
                }
            } message: {
                Text(settingsMessage ?? "")
            })
        view = AnyView(view.confirmationDialog("清理本地缓存？", isPresented: $showingClearCacheConfirmation, titleVisibility: .visible) {
                Button("清理缓存", role: .destructive) {
                    Task {
                        do {
                            try await newsStore.clearCache()
                            try await hotNewsStore.clearCache()
                            try await reportStore.clearCache()
                            settingsMessage = "本地新闻、热榜和报告缓存已清理"
                        } catch {
                            settingsMessage = "清理缓存失败：\(error.localizedDescription)"
                        }
                    }
                }
                Button("取消", role: .cancel) {}
            })
        view = AnyView(view.confirmationDialog("重置本机数据？", isPresented: $showingResetConfirmation, titleVisibility: .visible) {
                Button("重置数据", role: .destructive) {
                    isResettingData = true
                    Task {
                        defer { isResettingData = false }
                        do {
                            try await newsStore.clearCache()
                            try await hotNewsStore.clearCache()
                            try await reportStore.clearCache()
                            settingsStore.settings = AppSettings()
                            newsStore.settings = settingsStore.settings
                            ["api-base", "api-key", "ai-model", "notify-ntfy-token", "ntfy-token", "bark", "slack", "generic"].forEach { keychain.delete($0) }
                            settingsMessage = "本机数据和配置已重置"
                            showingSettingsMessage = true
                        } catch {
                            settingsMessage = "重置失败：\(error.localizedDescription)"
                            showingSettingsMessage = true
                        }
                    }
                }
                Button("取消", role: .cancel) {}
            })
        return view
    }

    private var settingsNavigation: AnyView {
        AnyView(
            NavigationStack {
                settingsRootContent
                    .navigationTitle("配置中心")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(AppTheme.background, for: .navigationBar)
                    .scrollContentBackground(.hidden)
                    .background(IntelligenceScreenBackground())
                    .tint(AppTheme.cyan)
                    .navigationDestination(for: SettingsCategory.self) { category in
                        categoryDestination(category)
                    }
            }
        )
    }

    private func categoryDestination(_ category: SettingsCategory) -> AnyView {
        AnyView(
            Form {
                categoryContent(category)
                    .listRowBackground(AppTheme.card.opacity(0.82))
            }
            .environment(\.defaultMinListRowHeight, 52)
            .listSectionSpacing(18)
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .navigationTitle(category.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .scrollContentBackground(.hidden)
            .background(IntelligenceScreenBackground())
            .tint(AppTheme.cyan)
        )
    }

    private var settingsRootContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                PageVisualBanner(assetName: "TrendRadar-SettingsHero", height: 118)
                SettingsOverviewSection(
                    platformsEnabled: settingsStore.settings.platformsEnabled,
                    rssEnabled: settingsStore.settings.rssEnabled,
                    aiEnabled: settingsStore.settings.ai.enabled
                )
                SettingsCategoriesSection()
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
        case .health:
            SystemHealthView()
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
            TextField("输入测试标题，预览匹配结果", text: $keywordPreviewText, axis: .vertical)
            if !keywordPreviewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let preview = FilterEngine(settings: settingsStore.settings).preview(
                    NewsItem(id: "keyword-preview", title: keywordPreviewText, source: "preview")
                )
                Label(
                    preview.matches ? "预计匹配当前情报规则" : "当前标题会被过滤",
                    systemImage: preview.matches ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(preview.matches ? AppTheme.green : AppTheme.red)
                if !preview.matchedRules.isEmpty {
                    Text("命中：" + preview.matchedRules.joined(separator: "、"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
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
            Button {
                testAIAvailability()
            } label: {
                Label(isTestingAI ? "正在检测 AI 服务..." : "检测 AI 配置可用性", systemImage: "checkmark.shield")
            }
            .disabled(isTestingAI)
            if let aiAvailabilityMessage {
                Text(aiAvailabilityMessage)
                    .font(.caption)
                    .foregroundStyle(aiAvailabilityMessage.hasPrefix("AI 配置可用") ? AppTheme.green : AppTheme.red)
            }
        }
    }

    private var displaySection: some View {
        Section("展示区域") {
            Picker("外观主题", selection: $settingsStore.settings.display.appearance) {
                ForEach(AppAppearance.allCases) { appearance in
                    Text(appearance.title).tag(appearance)
                }
            }
            .pickerStyle(.segmented)
            LabeledContent("内置字体", value: "HarmonyOS Sans SC")
            AppearancePreview(
                appearance: settingsStore.settings.display.appearance,
                highContrast: settingsStore.settings.display.highContrast,
                reduceTransparency: settingsStore.settings.display.reduceTransparency
            )
            TypographyPreview(scale: settingsStore.settings.display.fontScale)
            Toggle("高对比度", isOn: $settingsStore.settings.display.highContrast)
            Text("增强卡片边界与内容区分，适合强光环境。")
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textSecondary)
            Toggle("减少透明效果", isOn: $settingsStore.settings.display.reduceTransparency)
            Text("使用实色卡片并减少背景光效。")
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textSecondary)
            Toggle("热榜区域", isOn: $settingsStore.settings.display.showHotlist)
            Toggle("新增热点区域", isOn: $settingsStore.settings.display.showNewItems)
            Toggle("RSS 区域", isOn: $settingsStore.settings.display.showRSS)
            Toggle("独立展示区", isOn: $settingsStore.settings.display.showStandalone)
            Toggle("AI 分析区域", isOn: $settingsStore.settings.display.showAIAnalysis)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("字体大小")
                    Spacer()
                    Text(fontScaleLabel)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $settingsStore.settings.display.fontScale, in: 0.70...1.45, step: 0.05)
                HStack {
                    Text("最小 70%")
                    Spacer()
                    Text("最大 145%")
                }
                .font(AppTheme.metadataFont)
                .foregroundStyle(AppTheme.textTertiary)
                Text("应用到全部界面与内容；阅读器正文仍可单独调整。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("内置 Thin、Light、Regular、Medium 四档，许可说明随应用一并提供。")
                    .font(AppTheme.metadataFont)
                    .foregroundStyle(AppTheme.textTertiary)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("界面密度")
                    Spacer()
                    Text(uiScaleLabel)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $settingsStore.settings.display.uiScale, in: 0.90...1.15, step: 0.05)
                Text("调整表单行高、按钮和系统控件尺寸。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("卡片间距")
                    Spacer()
                    Text("\(Int(settingsStore.settings.display.cardSpacing)) pt")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $settingsStore.settings.display.cardSpacing, in: 8...24, step: 1)
            }
            Button("恢复默认显示设置") {
                settingsStore.settings.display.appearance = .dark
                settingsStore.settings.display.fontStyle = .system
                settingsStore.settings.display.highContrast = false
                settingsStore.settings.display.reduceTransparency = false
                settingsStore.settings.display.fontScale = 1.0
                settingsStore.settings.display.uiScale = 1.0
                settingsStore.settings.display.cardSpacing = 14.0
            }
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
                .disabled(!settingsStore.settings.aiTranslation.enabled)
            Toggle("订阅阅读支持翻译", isOn: $settingsStore.settings.aiTranslation.translateRSS)
                .disabled(!settingsStore.settings.aiTranslation.enabled)
            TextField("提示词文件", text: $settingsStore.settings.aiTranslation.promptFile)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .disabled(!settingsStore.settings.aiTranslation.enabled)
            Text("当前支持在订阅列表、情报详情和离线阅读器中按需翻译；译文保存在本机。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var notificationSection: some View {
        Section("本地提醒") {
            Toggle("启用通知总开关", isOn: $settingsStore.settings.notification.enabled)
            Toggle("允许本地提醒", isOn: $settingsStore.settings.notification.localAlerts)
            Toggle("提醒声音", isOn: $settingsStore.settings.notification.soundEnabled)
            VStack(alignment: .leading, spacing: 10) {
                Image("TrendRadar-Webhook")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 130)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                Text("报告 Webhook（本机实际投递）")
                    .font(.subheadline).foregroundStyle(AppTheme.cyan)
            }
            SecureField("飞书 Webhook", text: channelBinding("feishu"))
            SecureField("钉钉 Webhook", text: channelBinding("dingtalk"))
            SecureField("企业微信 Webhook", text: channelBinding("wework"))
            TextField("企业微信消息类型", text: $settingsStore.settings.notification.channels.weworkMessageType)
            SecureField("Telegram Bot Token", text: channelBinding("telegram-token"))
            TextField("Telegram Chat ID", text: channelBinding("telegram-chat"))
            TextField("邮件发件人", text: $settingsStore.settings.notification.channels.emailFrom)
                .disabled(true)
            SecureField("邮件密码或授权码", text: channelBinding("email-password"))
                .disabled(true)
            TextField("邮件收件人（逗号分隔）", text: $settingsStore.settings.notification.channels.emailTo)
                .disabled(true)
            TextField("SMTP 服务器", text: $settingsStore.settings.notification.channels.emailSMTPServer)
                .disabled(true)
            TextField("SMTP 端口", text: $settingsStore.settings.notification.channels.emailSMTPPort)
                .disabled(true)
            Text("邮件 SMTP 暂未接入；以上字段仅用于兼容既有配置，不参与实际投递。")
                .font(.caption).foregroundStyle(.secondary)
            TextField("ntfy 服务地址", text: $settingsStore.settings.notification.channels.ntfyServerURL)
            TextField("ntfy 主题", text: $settingsStore.settings.notification.channels.ntfyTopic)
            SecureField("ntfy Token", text: channelBinding("ntfy-token"))
            SecureField("Bark URL", text: channelBinding("bark"))
            SecureField("Slack Webhook", text: channelBinding("slack"))
            SecureField("通用 Webhook", text: channelBinding("generic"))
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            TextField("通用 JSON Payload 模板", text: $settingsStore.settings.notification.channels.genericPayloadTemplate, axis: .vertical)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            Text("留空默认发送 {title, content, report_type, generated_at}；模板支持 {title}、{content}、{markdown}、{html}、{report_json}、{report_type}、{generated_at}、{batch_index}、{batch_total}。占位符应位于 JSON 字符串值中。")
                .font(.caption).foregroundStyle(.secondary)
            NavigationLink {
                ReportOutputPreviewView(settings: settingsStore.settings)
            } label: {
                Label("预览 Markdown / HTML / JSON", systemImage: "eye")
            }
            Button {
                isTestingWebhook = true
                Task {
                    let result = await GenericWebhookService().sendTest(settings: settingsStore.settings)
                    await MainActor.run {
                        isTestingWebhook = false
                        settingsMessage = result.success ? "Webhook 测试发送成功（HTTP \(result.status ?? 0)，尝试 \(result.attempts) 次）" : "Webhook 测试失败：\(result.message)"
                    }
                }
            } label: {
                HStack {
                    Label(isTestingWebhook ? "正在测试 Webhook…" : "测试通用 Webhook", systemImage: "paperplane")
                    Spacer()
                    if isTestingWebhook { ProgressView() }
                }
            }
            .disabled(isTestingWebhook)
            if let last = GenericWebhookService.records().first {
                Text(last.success
                     ? "最近一次 Webhook 投递成功：HTTP \(last.status ?? 0) · \(last.createdAt.formatted(date: .omitted, time: .shortened))"
                     : "最近一次 Webhook 投递失败：\(last.message)")
                    .font(.caption)
                    .foregroundStyle(last.success ? AppTheme.green : AppTheme.red)
            }
            Text("纯 iOS 当前可实际投递飞书、钉钉、企业微信、Slack、Bark、ntfy、Telegram 和通用 Webhook；凭据只保存在本机 Keychain。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var storageSection: some View {
        Section("本地与远程存储") {
            Picker("存储后端", selection: $settingsStore.settings.storage.backend) {
                Text("自动选择").tag("auto")
                Text("本地").tag("local")
            }
            Toggle("SQLite 主存储", isOn: $settingsStore.settings.storage.sqliteEnabled)
            Toggle("生成 TXT 快照", isOn: $settingsStore.settings.storage.txtEnabled)
            Toggle("生成 HTML 报告", isOn: $settingsStore.settings.storage.htmlEnabled)
            TextField("本地数据目录", text: $settingsStore.settings.storage.localDataDirectory)
            Stepper("本地保留天数：\(settingsStore.settings.storage.localRetentionDays == 0 ? "永久" : "\(settingsStore.settings.storage.localRetentionDays)")", value: $settingsStore.settings.storage.localRetentionDays, in: 0...3650)
            Text("远程 S3、账号同步和服务端推送未接入纯本地 iPhone 数据链路。")
                .font(.caption).foregroundStyle(.secondary)
            Button("清理本地缓存", role: .destructive) {
                showingClearCacheConfirmation = true
            }
            Text("清理新闻、热榜排名历史和本地报告，不会修改设置或 Keychain 密钥。")
                .font(.caption).foregroundStyle(.secondary)
            Button {
                showingResetConfirmation = true
            } label: {
                HStack {
                    Text(isResettingData ? "正在重置本机数据…" : "重置本机数据")
                    if isResettingData {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(isResettingData)
            Text("LiveContainer 可能保留同一 Bundle ID 的容器和 Keychain。重装后仍看到旧数据时，使用此按钮清除新闻、报告、设置和 AI 密钥。")
                .font(.caption).foregroundStyle(.secondary)
            Text("S3/R2、账号同步和服务端推送属于可选远程能力。纯本地模式保持独立运行。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var fontScaleLabel: String {
        String(format: "%.0f%%", settingsStore.settings.display.fontScale * 100)
    }

    private var uiScaleLabel: String {
        String(format: "%.0f%%", settingsStore.settings.display.uiScale * 100)
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
            "ntfy-token": "notify-ntfy-token", "bark": "notify-bark", "slack": "notify-slack",
            "generic": "notify-generic", "s3-access": "storage-s3-access", "s3-secret": "storage-s3-secret"
        ]
        for (field, key) in secretKeys { keychain.write(channelSecrets[field] ?? "", for: key) }
        newsStore.settings = settingsStore.settings
        originalSettings = settingsStore.settings
        BackgroundRefreshService.schedule(after: settingsStore.settings.refreshInterval * 60, enabled: settingsStore.settings.scheduleEnabled)
        isSaveConfirmation = true
        settingsMessage = "设置已保存"
        showingSettingsMessage = true
        if settingsStore.settings.ai.enabled && settingsStore.settings.aiAnalysis.enabled {
            isTestingAI = true
            aiAvailabilityMessage = "正在检测 AI 配置..."
            let savedSettings = settingsStore.settings
            Task {
                do {
                    try await AIService().checkAvailability(settings: savedSettings)
                    await MainActor.run {
                        aiAvailabilityMessage = "AI 配置可用：接口、密钥和模型检测通过"
                        isTestingAI = false
                    }
                } catch {
                    await MainActor.run {
                        aiAvailabilityMessage = "AI 配置不可用：\(error.localizedDescription)"
                        isTestingAI = false
                    }
                }
            }
        }
    }

    private func testAIAvailability() {
        isTestingAI = true
        aiAvailabilityMessage = nil
        keychain.write(apiBase.trimmingCharacters(in: .whitespacesAndNewlines), for: "api-base")
        keychain.write(apiKey, for: "api-key")
        keychain.write(aiModel.trimmingCharacters(in: .whitespacesAndNewlines), for: "ai-model")
        let settings = settingsStore.settings
        Task {
            do {
                try await AIService().checkAvailability(settings: settings)
                await MainActor.run {
                    aiAvailabilityMessage = "AI 配置可用：接口、密钥和模型检测通过"
                    isTestingAI = false
                }
            } catch {
                await MainActor.run {
                    aiAvailabilityMessage = "AI 配置不可用：\(error.localizedDescription)"
                    isTestingAI = false
                }
            }
        }
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

private struct SystemHealthView: View {
    @EnvironmentObject private var newsStore: NewsStore
    @EnvironmentObject private var hotNewsStore: HotNewsStore
    @State private var execution: PipelineExecutionReport?
    @State private var isRunning = false
    @State private var message: String?

    private var failureCount: Int { newsStore.sourceFailures.count + hotNewsStore.sourceFailures.count }

    var body: some View {
        Section("系统状态") {
            Label(failureCount == 0 ? "系统状态良好" : "发现 \(failureCount) 个异常来源", systemImage: failureCount == 0 ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(failureCount == 0 ? AppTheme.green : AppTheme.yellow)
            LabeledContent("RSS 缓存", value: "\(newsStore.items.count) 条")
            LabeledContent("热榜缓存", value: "\(hotNewsStore.items.count) 条")
            if let execution {
                LabeledContent("最近触发", value: execution.trigger.rawValue)
                LabeledContent("阶段耗时", value: String(format: "%.2f 秒", execution.duration))
                LabeledContent("投递状态", value: execution.deliveryStatus.rawValue)
                ForEach(Array(execution.stageResults.enumerated()), id: \.offset) { _, stage in
                    HStack {
                        Image(systemName: stage.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(stage.success ? AppTheme.green : AppTheme.red)
                        VStack(alignment: .leading) {
                            Text(stage.name)
                            if let detail = stage.message { Text(detail).font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer(); Text(String(format: "%.2fs", stage.duration)).font(.caption.monospacedDigit())
                    }
                }
            } else {
                Text("尚无流水线诊断记录").foregroundStyle(.secondary)
            }
            Button {
                isRunning = true
                Task {
                    do { _ = try await RefreshPipelineExecutor.shared.execute(context: PipelineExecutionContext(trigger: .manual)); message = "重新初始化完成" }
                    catch { message = "重新初始化失败：\(error.localizedDescription)" }
                    execution = await PipelineDiagnosticsStore.shared.load(); isRunning = false
                }
            } label: { Label(isRunning ? "正在重新初始化…" : "重新初始化", systemImage: "arrow.clockwise") }
                .disabled(isRunning)
            Button("清空诊断日志", role: .destructive) {
                Task { await PipelineDiagnosticsStore.shared.clear(); execution = nil }
            }
            if let message { Text(message).font(.caption).foregroundStyle(.secondary) }
        }
        .task { execution = await PipelineDiagnosticsStore.shared.load() }
    }
}

private struct AppearancePreview: View {
    let appearance: AppAppearance
    let highContrast: Bool
    let reduceTransparency: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.heroGradient)
                HStack(spacing: 5) {
                    Circle().fill(AppTheme.electricBlue)
                    Circle().fill(AppTheme.violet)
                    Circle().fill(AppTheme.brandMagenta)
                }
                .frame(width: 58)
                .padding(12)
            }
            .frame(width: 82, height: 62)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(appearance.title)
                    .font(AppTheme.cardTitleFont)
                    .foregroundStyle(AppTheme.textPrimary)
                Text([highContrast ? "高对比" : "标准对比", reduceTransparency ? "实色卡片" : "材质卡片"].joined(separator: " · "))
                    .font(AppTheme.metadataFont)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: appearance == .system ? "iphone" : appearance == .dark ? "moon.stars.fill" : "sun.max.fill")
                .foregroundStyle(AppTheme.brandCyan)
                .accessibilityHidden(true)
        }
        .padding(12)
        .intelligenceCard(tint: AppTheme.brandIndigo, cornerRadius: 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("外观预览，\(appearance.title)，\(highContrast ? "高对比" : "标准对比")，\(reduceTransparency ? "实色卡片" : "材质卡片")")
    }
}

private struct TypographyPreview: View {
    let scale: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("趋势情报预览")
                .font(.custom("HarmonyOS_Sans_SC_Medium", fixedSize: 18 * scale))
                .foregroundStyle(AppTheme.textPrimary)
            Text("标题清晰、正文耐读、数字层级明确")
                .font(.custom("HarmonyOS_Sans_SC_Regular", fixedSize: 14 * scale))
                .foregroundStyle(AppTheme.textSecondary)
            Text("#01  ·  12 个来源  ·  刚刚更新")
                .font(.custom("HarmonyOS_Sans_SC_Light", fixedSize: 12 * scale).monospacedDigit())
                .foregroundStyle(AppTheme.brandCyan)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .intelligenceCard(tint: AppTheme.brandCyan, cornerRadius: 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("字体效果预览")
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
    @State private var group: String
    @State private var requestTimeout: Int
    @State private var retryCount: Int
    @State private var userAgent: String
    @State private var requestHeaders: String
    private let onSave: (ConfigFeed) -> Void
    private let onDelete: (() -> Void)?

    init(feed: ConfigFeed?, onSave: @escaping (ConfigFeed) -> Void, onDelete: (() -> Void)? = nil) {
        _id = State(initialValue: feed?.id ?? "custom-feed")
        _name = State(initialValue: feed?.name ?? "自定义源")
        _url = State(initialValue: feed?.url ?? "https://example.com/feed.xml")
        _isEnabled = State(initialValue: feed?.isEnabled ?? true)
        _maxAgeDays = State(initialValue: feed?.maxAgeDays ?? 0)
        _group = State(initialValue: feed?.group ?? "未分组")
        _requestTimeout = State(initialValue: feed?.requestTimeout ?? 20)
        _retryCount = State(initialValue: feed?.retryCount ?? 3)
        _userAgent = State(initialValue: feed?.userAgent ?? "TrendRadar/1.0")
        _requestHeaders = State(initialValue: feed?.requestHeaders ?? "")
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            ZStack {
                IntelligenceScreenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        editorSection(title: "RSS 基本信息", icon: "dot.radiowaves.left.and.right") {
                            editorField("唯一 ID", text: $id, systemImage: "number")
                            editorField("显示名称", text: $name, systemImage: "textformat")
                            editorField("订阅地址", text: $url, systemImage: "link", autocorrect: false)
                            Toggle("启用此源", isOn: $isEnabled)
                        }
                        editorSection(title: "采集策略", icon: "slider.horizontal.3") {
                            Stepper("单源最大年龄：\(maxAgeDays == 0 ? "跟随全局" : "\(maxAgeDays) 天")", value: $maxAgeDays, in: 0...30)
                            editorField("主题分组", text: $group, systemImage: "folder")
                            Stepper("请求超时：\(requestTimeout) 秒", value: $requestTimeout, in: 5...120, step: 5)
                            Stepper("失败重试：\(retryCount) 次", value: $retryCount, in: 1...5)
                            editorField("User-Agent", text: $userAgent, systemImage: "person.text.rectangle", autocorrect: false)
                            TextField("自定义请求头，每行 Name: Value", text: $requestHeaders, axis: .vertical)
                                .lineLimit(3...8).textInputAutocapitalization(.never).autocorrectionDisabled()
                                .padding(12).background(AppTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        if let onDelete {
                            Button(role: .destructive) { onDelete(); dismiss() } label: {
                                Label("删除此 RSS 源", systemImage: "trash").frame(maxWidth: .infinity)
                            }.buttonStyle(OutlineButtonStyle())
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("编辑 RSS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let normalizedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
                        let normalizedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !normalizedID.isEmpty, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                              URL(string: normalizedURL) != nil else { return }
                        onSave(ConfigFeed(id: normalizedID, name: name, url: normalizedURL, isEnabled: isEnabled, maxAgeDays: maxAgeDays, group: group.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未分组" : group, requestTimeout: requestTimeout, retryCount: retryCount, userAgent: userAgent, requestHeaders: requestHeaders))
                        dismiss()
                    }
                }
            }
            .tint(AppTheme.cyan)
        }
    }

    private func editorSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(AppTheme.cardTitleFont).foregroundStyle(AppTheme.textPrimary)
            content()
        }
        .padding(16)
        .intelligenceCard(tint: AppTheme.brandCyan, cornerRadius: 20)
    }

    private func editorField(_ title: String, text: Binding<String>, systemImage: String, autocorrect: Bool = true) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage).foregroundStyle(AppTheme.brandCyan).frame(width: 22)
            TextField(title, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(!autocorrect)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 46)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
