# OLED屏幕保护时钟

全屏 OLED 屏保时钟，支持经典弹跳与 HTC 翻页样式。macOS / iOS 通用。

## 本地化

- 简体中文（默认）
- English
- 繁體中文
- 日本語

App 显示名称：**OLED屏幕保护时钟**（见 `InfoPlist.xcstrings`）。

## 开发

```bash
xcodebuild -scheme time -destination 'platform=macOS' build
xcodebuild test -scheme time -destination 'platform=macOS' -only-testing:timeTests
```
