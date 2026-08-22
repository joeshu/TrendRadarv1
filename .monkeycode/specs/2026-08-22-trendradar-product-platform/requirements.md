# TrendRadar 全量产品需求文档

## Introduction

TrendRadar 是一款纯本地优先的 iOS 情报聚合应用。应用从 NewsNow 热榜和 RSS 源采集内容，在设备端完成去重、过滤、快照、趋势计算、AI 洞察、收藏归档和通知调度。产品由 Radar、Feeds、Insight、Archive、Settings 五个模块组成，所有模块共享本地数据模型和配置状态。

本需求基于 iOS 17、SwiftUI、SwiftData、系统通知和可选的用户自有兼容 API。第一阶段优先完成真实数据驱动的核心链路，后续阶段按任务清单逐步扩展。

## Glossary

- **情报条目**：来自热榜或 RSS 的统一内容记录。
- **热榜平台**：NewsNow API 支持的榜单来源。
- **主题**：经过规范化和跨平台去重后的讨论对象。
- **数据快照**：在指定采集时间保存的不可变条目集合。
- **报告快照**：报告生成时保存的新闻、热榜、配置和 AI 内容副本。
- **独立展示源**：绕过普通关键词过滤、单独呈现的配置数据源。
- **Insight**：基于本地热榜、RSS 和历史快照生成 AI 洞察的模块。
- **Archive**：保存、搜索、回溯和导出历史情报资产的模块。

## Product Principles

1. 真实数据优先：页面中的排名、趋势、统计和 AI 引用必须来自本地可追溯数据。
2. 本地可用优先：网络、AI 或单个平台失败时，已缓存内容继续可读。
3. 快照不可变：历史报告和历史时间点展示生成时内容。
4. 配置实时生效：关键词、平台、显示和调度设置修改后，各模块使用同一份最新配置。
5. 可诊断：每次采集、解析、AI 和持久化失败都提供来源、时间和可读原因。

## Requirements

### Requirement 1: Radar 热榜情报流

**User Story:** 作为用户，我希望在 Radar 中查看多平台实时热榜，以便从一个入口掌握正在发生的事件。

#### Acceptance Criteria

1. WHEN 用户打开 Radar，THE 系统 SHALL 从本地缓存加载热榜内容并展示最近一次更新时间。
2. WHEN 用户执行下拉刷新，THE 系统 SHALL 按配置启用的平台分批获取 NewsNow 数据，并在成功返回后更新本地热榜快照。
3. WHEN 单个平台获取失败，THE 系统 SHALL 保留该平台最近一次有效内容，并展示平台级失败原因。
4. WHEN 所有平台获取失败，THE 系统 SHALL 保留可用缓存并提供手动重试入口。
5. WHEN 热榜条目来自多个平台且主题规范化结果一致，THE 系统 SHALL 合并主题并展示参与讨论的平台数量。

### Requirement 2: Radar 筛选与主题交互

**User Story:** 作为用户，我希望按平台、关键词和主题筛选情报，以便快速聚焦关注内容。

#### Acceptance Criteria

1. WHEN 用户选择平台筛选器，THE 系统 SHALL 仅展示该平台的相关条目或主题。
2. WHEN 用户配置包含关键词，THE 系统 SHALL 保留标题匹配关键词的条目。
3. WHEN 用户配置必须关键词，THE 系统 SHALL 仅保留同时满足必须关键词的条目。
4. WHEN 用户配置排除关键词，THE 系统 SHALL 从结果中移除标题命中排除关键词的条目。
5. WHEN 用户打开主题详情，THE 系统 SHALL 展示跨平台条目、排名变化、历史快照和可用原文链接。
6. WHEN 用户收藏、分享或屏蔽主题，THE 系统 SHALL 持久化操作结果并立即更新当前列表。

### Requirement 3: Radar 趋势指标

**User Story:** 作为用户，我希望看到排名和持续时间变化，以便识别新出现和快速升温的主题。

#### Acceptance Criteria

1. WHEN 当前快照与上一快照存在同一条目，THE 系统 SHALL 计算排名变化并展示上升、下降或稳定状态。
2. WHEN 条目在历史快照中首次出现，THE 系统 SHALL 展示 NEW 状态。
3. WHEN 主题具有连续快照记录，THE 系统 SHALL 计算上榜持续时间。
4. WHEN 历史数据不足以计算趋势，THE 系统 SHALL 展示数据不足状态。

### Requirement 4: Feeds RSS 订阅与阅读

**User Story:** 作为用户，我希望管理 RSS/Atom 来源并离线阅读文章，以便持续获取深度内容。

#### Acceptance Criteria

1. WHEN 用户添加 RSS/Atom 地址，THE 系统 SHALL 解析来源元数据和文章条目并保存来源配置。
2. WHEN RSS/XML 解析失败，THE 系统 SHALL 展示来源地址、解析阶段和可读错误。
3. WHEN RSS 来源连续三次刷新失败，THE 系统 SHALL 标记来源健康状态并在设置中提示。
4. WHEN 用户打开 Feeds，THE 系统 SHALL 按发布时间倒序展示文章，并支持未读、来源和关键词筛选。
5. WHEN 用户打开文章详情，THE 系统 SHALL 优先展示本地缓存正文，网络可用时允许更新正文。
6. WHEN 用户调整阅读设置，THE 系统 SHALL 在阅读器中应用字号、深色背景和排版配置。
7. WHEN RSS 文章与热榜主题匹配，THE 系统 SHALL 展示关联热榜标记和关联主题入口。

### Requirement 5: Insight AI 洞察

**User Story:** 作为用户，我希望基于真实情报生成可追溯的 AI 洞察，以便理解趋势并采取行动。

#### Acceptance Criteria

1. WHEN 用户选择 Current、Daily、Incremental 或手动报告，THE 系统 SHALL 使用对应时间范围和本地快照生成报告。
2. WHEN AI 服务返回分析结果，THE 系统 SHALL 保存模型、生成时间、输入快照标识和正文。
3. WHEN AI 分析结论引用情报条目，THE 系统 SHALL 保存对应条目标识和原文链接。
4. WHEN 用户选择主题深度分析，THE 系统 SHALL 展示跨平台传播时间线、历史热度和关联主题。
5. WHEN 用户发送自然语言问题，THE 系统 SHALL 使用当前本地上下文生成回答，并为可验证结论展示引用。
6. WHEN AI 服务不可用或超出配置限制，THE 系统 SHALL 展示失败原因并保留原始情报与已有报告。
7. WHEN 用户启用情绪分析，THE 系统 SHALL 标记分析结果的模型、时间和样本数量，并区分真实计算值与未计算状态。

### Requirement 6: Archive 历史与收藏

**User Story:** 作为用户，我希望长期保存和回溯情报资产，以便复盘热点变化和个人关注记录。

#### Acceptance Criteria

1. WHEN 用户收藏热榜条目、RSS 文章或 AI 报告，THE 系统 SHALL 保存收藏类型、来源、时间和内容快照。
2. WHEN 用户为收藏添加标签或笔记，THE 系统 SHALL 保存并支持后续编辑和搜索。
3. WHEN 用户选择历史日期，THE 系统 SHALL 展示该日期可用的热榜快照和数据完整度。
4. WHEN 用户选择两个历史时间点，THE 系统 SHALL 展示新增、消失、排名变化和持续主题。
5. WHEN 用户搜索主题关键词，THE 系统 SHALL 展示时间范围内的热度轨迹和平台分布。
6. WHEN 用户导出历史内容，THE 系统 SHALL 生成可分享的 Markdown 或纯文本内容，并保留数据来源。
7. WHEN 历史数据超过保留策略，THE 系统 SHALL 清理非收藏历史记录并保留收藏和报告快照。

### Requirement 7: Settings 全局配置

**User Story:** 作为用户，我希望集中管理来源、关键词、AI、通知、显示和数据策略，以便控制应用行为。

#### Acceptance Criteria

1. WHEN 用户修改平台、RSS 或关键词配置，THE 系统 SHALL 在下一次过滤和刷新中使用新配置。
2. WHEN 用户保存 AI 配置，THE 系统 SHALL 将 API 密钥保存到 Keychain，并在界面中脱敏展示。
3. WHEN 用户设置刷新频率和免打扰时段，THE 系统 SHALL 按配置安排本地刷新和通知。
4. WHEN 用户修改主题、字号或默认入口，THE 系统 SHALL 在后续页面生命周期中应用配置。
5. WHEN 用户查看存储管理，THE 系统 SHALL 展示本地数据类型、保留策略和清理入口。
6. WHEN 用户执行重置本机数据，THE 系统 SHALL 清理本地内容、配置和项目使用的 Keychain 密钥，并展示成功或失败结果。
7. WHEN 用户查看关于与帮助，THE 系统 SHALL 展示版本、构建号、隐私说明、开源致谢和反馈入口。

### Requirement 8: 本地数据一致性与可靠性

**User Story:** 作为用户，我希望应用在网络波动、重启和 LiveContainer 环境下保持数据安全，以便持续使用。

#### Acceptance Criteria

1. THE 系统 SHALL 使用统一的本地存储访问层处理新闻、热榜、报告、收藏和历史快照。
2. WHEN 多个模块同时读写本地数据，THE 系统 SHALL 串行化持久化操作并保持可读取状态。
3. WHEN 应用重启，THE 系统 SHALL 恢复本地列表、收藏、报告、配置和历史数据。
4. WHEN 单个异步任务失败，THE 系统 SHALL 将错误限制在对应任务并保持前台界面可交互。
5. WHEN 数据迁移或存储初始化失败，THE 系统 SHALL 使用隔离存储或降级存储并展示可诊断状态。

## Scope and Phases

### Phase 1: Radar 主链路

统一热榜模型、35+ 平台配置、分批刷新、跨平台主题去重、平台筛选、排名变化和热榜快照。

### Phase 2: Feeds 深度阅读

RSS/Atom 解析、来源分组、健康检测、文章正文缓存、阅读器、未读管理和热榜关联。

### Phase 3: Insight 洞察中心

报告中心升级、情绪分析、主题深度分析、历史对比、AI 引用和自然语言查询。

### Phase 4: Archive 情报档案

统一收藏、标签笔记、日历回溯、时间轴、主题轨迹、跨平台对比和导出。

### Phase 5: Settings 完整控制中心

关键词编辑器、AI 提供商、用量、通知调度、显示体验、存储管理、隐私帮助和反馈。

### Phase 6: 可靠性与交付

迁移、离线、后台任务、性能、测试、构建、真机回归和文档同步。

## Product Decisions

1. 第一阶段继续使用 NewsNow API 的 `id` 参数和当前本地存储基础设施。
2. 主题去重使用可解释的规范化规则作为第一版，AI 语义聚类进入后续迭代。
3. PDF、图片海报、iCloud CloudKit 和远程同步进入后续范围，先完成本地 Markdown/纯文本导出。
4. AI 功能使用用户自行配置的项目环境和 Keychain 凭据，应用不内置服务端密钥。
5. BGAppRefreshTask 仅在完成启动稳定性和真机验证后恢复，前台功能保持独立可运行。
