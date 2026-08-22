# TrendRadar iOS 构建产物

`TrendRadar-iOS-sideload` 包含两个 IPA：

- `TrendRadar-unsigned.ipa`: 供 AltStore、SideStore、Sideloadly 等工具重新签名。
- `TrendRadar-adhoc.ipa`: ad-hoc 签名版本，仅适用于 TrollStore/CoreTrust bypass 等兼容环境；普通 iPhone 仍需要有效开发者签名。
- `SHA256SUMS.txt`: 构建产物校验值。

普通 iOS 设备不能直接运行完全未签名 IPA。导入侧载工具后，应使用自己的 Apple ID 或签名证书完成安装。HTML 报告可以从报告详情的菜单导出，再通过分享面板发送到微信、邮件或“文件”。
