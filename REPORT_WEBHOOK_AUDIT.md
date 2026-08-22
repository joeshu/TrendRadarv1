# TrendRadar iOS 报告与 Webhook 全面审计

日期：2026-08-23
基准：iOS 分支 `260821-feat-ios-pure-mobile`；主仓库现有 `trendradar/report` 与 `trendradar/notification`

## 一、结论

当前 iOS 版本实现的是“本地报告快照 + 通用 Markdown Webhook”，不是主仓库的“统一报告渲染 + 多渠道专用格式化”。因此差距不是某几个颜色或标题的问题，而是报告协议、数据层、渲染层、渠道层四层没有对齐。

最核心的断层：

1. iOS 报告数据模型没有完整表达主仓库报告数据；
2. iOS Markdown 只是简化文本，不是主仓库的通知渲染结果；
3. iOS HTML 是另一套极简模板，与主仓库 HTML 报告几乎不是同一种视觉产品；
4. iOS Webhook 默认只发送 `title/content` JSON，且 `content` 是简化 Markdown；
5. 飞书、钉钉、企业微信、Telegram、Slack、邮件、Bark、ntfy 等 iOS 配置字段目前没有对应的实际发送器；
6. iOS 忽略主仓库的区域顺序、热点词统计、独立展示区、新增区、失败区、排名轨迹、渠道格式差异。

所以现状下，即使 Webhook 成功，接收端也不可能自然呈现出主仓库报告的结构和视觉效果。

## 二、四条链路的现状

### 1. 数据生成链路

iOS：

`RSS/热榜采集 → FilterEngine/KeywordGroup → ReportGenerationService → ReportDetail`

主仓库：

`热榜统计/频次/排名轨迹/新增标题/RSS统计/独立展示/AI → report_data → 渲染器`

iOS 当前 `ReportDetail` 只有：报告标题、统计数字、AI 结构化结果、若干 section 和 item snapshot。主仓库使用的以下信息没有进入 iOS 报告的统一数据对象：

- 热点词及其出现次数、占比、热度等级；
- 每个热点词下的标题序号；
- 跨平台排名列表与排名时间线；
- 新增热点单独区域及 `NEW` 标记；
- RSS 新增区域；
- 独立展示区的来源分组；
- 失败平台/失败 RSS 源的报告区块；
- 更新版本信息；
- 主仓库的展示区域顺序和区域开关快照；
- 渠道级标题格式、链接格式和字节上限。

### 2. App 内报告详情

App 内是目前最完整的一条链，但它仍然是另一套深色卡片 UI：

- 头部：报告类型、标题、生成时间、AI 图标；
- 统计：情报、来源、未读、关键词、热榜、RSS 等数字卡片；
- AI：多个 `InsightPanel`；
- 内容：每个 section 一个卡片，条目垂直排列。

这套 UI 没有复用主仓库 HTML 的报告结构，也没有复用 Webhook 的内容结构。App 内看到的内容与分享 Markdown、导出 HTML、Webhook 内容并非同一份渲染结果。

### 3. Markdown / Webhook

`ReportFormatter.render(.markdown)` 当前只输出：

- 一级标题；
- 4 个统计字段；
- AI 的部分字段；
- section 标题；
- `- 标题 · 来源 · 排名`。

关键缺失：

- 标题没有 `[标题](URL)` 链接；
- 没有主仓库的 `📊 热点词汇统计`；
- 没有热点词计数、占比、热度等级和序号；
- 没有 `🆕 本次新增热点新闻`；
- 没有 RSS 分组和源计数；
- 没有独立展示区；
- 没有失败来源区；
- 没有排名轨迹和趋势；
- 没有稳定的报告 footer / 更新时间 / 版本信息；
- AI 的 `coreTrends`、`signals` 等结构化字段存在时，Markdown 可能不输出；
- 没有渠道格式转换。

Webhook 默认载荷当前是：

```json
{
  "title": "报告实际标题",
  "content": "简化 Markdown",
  "report_type": "daily",
  "generated_at": "...",
  "batch_index": 1,
  "batch_total": 1
}
```

主仓库通用 Webhook 的默认载荷是：

```json
{
  "title": "daily",
  "content": "经过 wework/Markdown 渲染器生成的完整报告正文"
}
```

二者的 `title` 语义、正文结构、分批策略和默认格式都不一致。

### 4. HTML 导出

iOS `ReportHTMLFormatter` 是 46 行左右的简化 HTML：

- 一个渐变头部；
- 一个 AI 段落；
- section 标题；
- article 标题、来源、摘要。

主仓库 HTML 包含：

- 报告头部和统计信息；
- 热点词 Tab；
- 热度等级和排名视觉；
- 新增热点区；
- RSS 分组区；
- 独立展示区；
- AI 富文本区块；
- 抓取异常区；
- section divider；
- 导出 Markdown / 图片等交互；
- 更完整的响应式样式。

因此 iOS HTML 不是主仓库 HTML 的移动版，而是一个独立的最低限度导出模板。

## 三、逐项差距矩阵

| 维度 | 主仓库 | iOS 当前 | 差距等级 |
|---|---|---|---|
| 报告 ID/批次 | 运行批次、时间窗口、增量状态 | 有批次 ID，但主要服务去重 | 中 |
| 报告标题 | 按报告类型和运行上下文 | 类型 + 时间 | 中 |
| 总情报数 | 热榜总量、匹配量、RSS 总量分开 | 只保留展示后的数量 | 高 |
| 热点词统计 | count、percentage、等级、标题列表 | 只有 keywordCount | 高 |
| 热榜标题 | 来源、PC/mobile URL、排名、排名轨迹、出现次数 | 标题、来源、URL、当前排名 | 高 |
| 新增热点 | 独立区域、过滤后新增数、NEW 标记 | 设置字段存在，但生成器未实现独立区域 | 高 |
| RSS | 源统计、分组、时间、摘要 | 有 section，但没有主仓库的 RSS 统计语义 | 中高 |
| 独立源点 | 单独平台/RSS 配置和最大条数 | AI 有 standaloneSummaries，但没有报告 section | 高 |
| AI | 核心趋势、争议、信号、情绪、建议、引用、独立源摘要 | 部分字段有，Markdown/HTML 没有完整输出 | 高 |
| 失败信息 | 平台、RSS 源、错误详情、部分成功状态 | 执行日志有，但报告正文没有 | 高 |
| 区域顺序 | configurable region order | `regionOrder` 字段存在但生成器固定 hotlist + RSS | 高 |
| Markdown | 渠道专用格式和链接 | 简化 plain/Markdown 两种 | 高 |
| HTML | 完整报告网页 | 极简独立模板 | 高 |
| 飞书 | post/rich text 专用 payload | 未实现 | 高 |
| 钉钉 | markdown payload | 未实现 | 高 |
| 企业微信 | markdown/text payload | 未实现 | 高 |
| Telegram | HTML payload | 未实现 | 高 |
| Slack | mrkdwn payload | 未实现 | 高 |
| 邮件 | HTML 报告 | 未实现 | 高 |
| Webhook 模板 | `{title}` `{content}`，主仓库语义 | 额外变量虽多，但默认正文不同 | 高 |
| 分批 | 渠道字节限制 + 批次头 + footer 保留 | 固定 10KB，按换行切分 | 高 |
| 链接安全 | 各渠道按语法转义 | iOS Markdown 条目没有 URL | 高 |

## 四、当前代码中的具体问题

### A. ReportGenerationService.swift

1. `makeSections()` 最终硬编码 `return hotlistSection + orderedRSSSections`，没有按 `settings.display.regionOrder` 排序；
2. `showNewItems`、`showStandalone`、`showStandalone` 相关配置没有真正生成对应 section；
3. `displayMode == "platform"` 只影响 RSS 分组，未实现主仓库 platform 模式的关键词标签和跨平台统计；
4. report 中没有保存抓取总量、失败源、更新时间、热点词统计和新增数据；
5. `windowStart` 对热榜使用 `publishedAt ?? firstSeenAt`，但多数热榜返回没有发布日期，日报/增量语义会退化；
6. URL 虽在 `ReportItemSnapshot` 中保存，但文本渲染器没有使用。

### B. ReportFormatter.swift

1. 文本输出过于扁平，section 内容只有一行一个标题；
2. Markdown item 应输出为带链接的标题，并带来源、时间、排名和趋势；
3. AI 字段输出不完整且字段之间没有统一层级；
4. 没有统一 footer、批次头、失败提示和统计摘要；
5. `.plainText` 与 `.markdown` 的差异只有标题符号和列表符号，未做渠道适配。

### C. ReportHTMLExport.swift

1. 只显示 `aiAnalysis.content`，忽略 core trends、signals、情绪、建议、引用等；
2. 没有统计卡片、热点词、趋势、NEW、失败区、独立区；
3. CSS 与 App 视觉接近，但与主仓库 HTML 视觉和信息架构不一致；
4. `escape()` 没有处理单引号，URL 放入属性时也没有专门的属性转义；
5. 每个条目都包成 article，但没有排名色阶、来源 tag、时间和可读性层次。

### D. GenericWebhookService.swift

1. 默认 payload 的 `title` 是完整报告标题，而主仓库是报告类型；
2. `content` 仅调用简化 `ReportFormatter`；
3. `markdown`、`html`、`report_json` 变量虽存在，但没有完整的主仓库兼容 schema；
4. 模板替换依赖“变量本身已经在 JSON 字符串内”，对 `{report_json}` 作为对象、数组和转义场景不够可靠；
5. 分批以 10KB 固定切分，缺少主仓库按渠道限制和批次头；
6. 失败时只发送一批后停止，主仓库的分批协议和 footer 保留策略没有对齐；
7. Webhook 没有识别飞书/钉钉/企业微信的原生 payload；
8. Webhook 投递记录没有保存 payload schema、渠道类型、批次内容摘要和响应 body；
9. URL 只读 Keychain，设置模型的 `genericWebhook` 字段和实际使用存在语义分裂风险。

## 五、应该怎样重构

### 第一阶段：建立统一报告协议（必须先做）

新增 `ReportPresentationModel`，从 `ReportDetail` 生成一次，所有出口只消费它：

```text
ReportPresentationModel
├── metadata: title/type/generatedAt/window/batch/status
├── summary: total/matched/new/hotlist/rss/source/platform/failed
├── regions: [newItems, hotlist, rss, standalone, aiAnalysis, failures]
├── topicStats: [{name,count,percentage,level,items}]
├── items: [{title,url,mobileURL,source,sourceType,time,rank,ranks,rankTrend,count,isNew,keyword}]
├── ai: {coreTrends,controversy,signals,sentiment,recommendation,citations,standalone}
└── footer: updatedAt/version/batch
```

所有区域必须尊重：

- `showHotlist`、`showNewItems`、`showRSS`、`showStandalone`、`showAIAnalysis`；
- `regionOrder`；
- `displayMode`；
- `maxNewsPerKeyword`；
- `rankThreshold`；
- 当前/日报/增量时间窗口。

### 第二阶段：统一 Markdown 渲染

新增 `ReportMarkdownRenderer`，输出主仓库风格的完整正文：

```markdown
# TrendRadar · 日报

> 更新时间：... · 模式：... · 批次：...

## 📊 数据概览
- 总计：...
- 热榜：...（平台 ...）
- RSS：...（来源 ...）
- 新增：...

## 🔥 热点词汇统计
| 热点 | 数量 | 占比 | 热度 |

## 🆕 本次新增热点新闻
- [标题](URL) · 来源 · 🆕 · 排名 ... · ...

## 🔥 热榜
### 平台/主题
- [标题](URL) · 来源 · #1 · ↑...

## 📰 RSS 订阅更新
### 来源
- [标题](URL) · 时间 · 摘要

## 🧠 AI 洞察
...

## ⚠️ 采集异常
...

---
生成于 ... · TrendRadar iOS
```

同一个 renderer 同时供：App 分享、Webhook 默认 content、纯文本降级。避免现在 App、HTML、Webhook 各写一套。

### 第三阶段：统一 HTML 视觉

将 HTML 输出改成与 App 的深色视觉和主仓库的信息架构一致：

- Hero：类型、时间、窗口、总量；
- summary grid：热榜/RSS/来源/新增/未读；
- topic chips/table；
- 区域卡片；
- item card：来源 tag、标题链接、摘要、时间、排名和趋势；
- AI insight card：趋势、争议、信号、情绪、建议；
- failures card；
- footer；
- responsive mobile/desktop CSS；
- 所有文本、链接、属性统一 escape。

### 第四阶段：渠道适配层

不要让通用 Webhook 伪装成所有渠道。应新增：

- `WebhookPayloadKind.genericJSON`
- `.feishuPost`
- `.dingtalkMarkdown`
- `.weworkMarkdown`
- `.telegramHTML`
- `.slackMrkdwn`
- `.plainText`

渠道 payload 只负责包装统一 renderer 生成的正文，不再各自拼新闻内容。

### 第五阶段：分批协议

统一使用 UTF-8 字节切分，保留：

- 批次头 `[第 x/y 批次]`；
- footer；
- section 边界；
- 单条新闻不拆断；
- 各平台限制：飞书、钉钉、企业微信、Telegram、Slack、通用 Webhook 分别配置；
- 批间隔和失败重试。

### 第六阶段：可视化回归测试

新增固定 fixture 报告，分别断言：

1. Markdown 标题、统计、链接、区域顺序、AI、异常区；
2. HTML 含同样区域和链接；
3. Webhook 默认 payload content 与 Markdown renderer 完全一致；
4. 自定义 JSON 模板解析；
5. 飞书/钉钉/企业微信包装字段；
6. 10KB/平台限制下分批不丢条目；
7. 空数据、AI 失败、部分源失败、首次运行全新增等边界场景。

## 六、建议实施顺序

### P0：内容一致性

- 做 `ReportPresentationModel`；
- 实现完整 Markdown renderer；
- 修复 regionOrder / new_items / standalone / failure sections；
- 条目补齐 URL、时间、排名趋势；
- Webhook 默认 content 改为完整 renderer。

### P1：视觉一致性

- 重写 HTML exporter；
- App 报告详情改为消费 presentation model；
- 同一份 fixture 做 Markdown、HTML、App 结构回归。

### P2：渠道一致性

- 实现原生飞书、钉钉、企业微信 payload；
- 再实现 Telegram、Slack、ntfy、Bark、邮件；
- 渠道配置和 Keychain 语义统一。

### P3：可运维性

- 增加 payload schema version；
- 投递记录增加 channel、batch、response 摘要；
- 设置页增加“预览 Markdown / HTML / JSON”；
- 增加 Webhook 测试 payload 类型选择；
- 增加报告导出和推送的 snapshot tests。

## 七、最终验收标准

同一份报告 fixture 必须满足：

- App 详情、Markdown 分享、HTML 导出、Webhook 默认 content 的区域集合一致；
- 区域顺序一致；
- 条目数量一致；
- 标题、来源、URL、排名、时间一致；
- AI 字段不丢失；
- 新增、独立源、失败来源不丢失；
- 不同渠道只改变包装格式，不改变报告事实内容；
- 分批后合并正文等于未分批正文（除批次头外）；
- 用户可以在设置中直接预览最终 Webhook JSON 和正文。
