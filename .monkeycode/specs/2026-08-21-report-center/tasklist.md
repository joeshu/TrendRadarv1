# 报告中心实施任务清单

## 1. 数据模型与持久化

- [x] 1.1 新增报告类型、状态、触发来源、统计和快照应用模型
- [x] 1.2 新增 SwiftData `ReportRecord` 和 `ReportItemRecord`
- [x] 1.3 扩展 `LocalStore` 的 ModelContainer schema 和报告 CRUD
- [x] 1.4 增加报告模型编码、快照隔离和删除级联测试

## 2. 报告生成

- [x] 2.1 实现 `ReportGenerationRequest` 和 `ReportGenerationService`
- [x] 2.2 实现报告类型、筛选结果、分组和统计计算
- [x] 2.3 实现生成批次去重和失败状态处理
- [x] 2.4 接入前台刷新、后台刷新和手动生成入口

## 3. 报告中心界面

- [x] 3.1 实现 `ReportStore` 列表、详情和筛选状态
- [x] 3.2 在主界面增加报告中心入口
- [x] 3.3 实现报告列表、搜索、类型筛选和空状态
- [x] 3.4 实现报告详情、新闻快照展示和原文跳转

## 4. 报告操作

- [x] 4.1 实现报告收藏和删除
- [x] 4.2 实现文本和 Markdown 分享
- [x] 4.3 实现按 `storage.local.retention_days` 的保留策略

## 5. 验证与交付

- [x] 5.1 增加单元测试、集成测试和 UI 关键路径测试
- [x] 5.2 完成工作区静态检查并修复已发现的 Swift 代码问题
- [ ] 5.3 通过 GitHub Actions 构建无签名 IPA
- [ ] 5.4 同步项目文档并提交推送
