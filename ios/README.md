# TrendRadar iOS

这是 TrendRadar 的纯手机运行版本。App 在 iPhone 本地完成热点抓取、RSS 解析、关键词过滤、SwiftData 持久化和本地通知，运行时不依赖项目后端。

## 生成 Xcode 工程

需要在 macOS 上安装 XcodeGen：

```bash
brew install xcodegen
xcodegen generate
open TrendRadar.xcodeproj
```

## 本地构建

```bash
xcodebuild -project TrendRadar.xcodeproj -scheme TrendRadar -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## 运行约束

- 最低 iOS 版本为 17.0。
- AI 配置保存在 iOS Keychain，App 不内置服务端密钥。
- 后台刷新由 iOS 系统调度，用户可以在 App 内手动刷新。
- 新闻数据使用 SwiftData 保存；旧版本的 `news.json` 会在首次读取时迁移到 SwiftData。
- App 的实际后台执行时间由 iOS 系统决定，设置中的刷新间隔用于提交最早执行时间。

## 无签名 IPA

GitHub Actions 提供 `Build Unsigned TrendRadar IPA` 工作流生成无签名 IPA。无签名 IPA 只适合作为侧载工具的输入文件，安装前需要使用 SideStore、AltStore、Sideloadly 或其他兼容工具完成重新签名。

无签名构建不需要 Apple Developer 证书、Provisioning Profile 或 App Store Connect Secret。侧载工具仍需要用户自己的 Apple 账号或签名服务，并且受 iOS 侧载有效期和设备限制影响。

推送以下内容到 `260821-feat-ios-pure-mobile` 分支时，Workflow 会自动运行：

- `ios/` 下的 Swift 源码
- `ios/project.yml`
- `.github/workflows/ios-unsigned.yml`

构建完成后，在 GitHub Actions 的 Artifacts 中下载 `TrendRadar-iOS-unsigned`。Artifact 保留 14 天。
