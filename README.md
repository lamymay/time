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
xcodebuild test -scheme time -destination 'platform=macOS' -only-testing:timeUITests
```

运行前请先在 Xcode **Stop** 掉正在调试的 `time`（否则会有暂停中的 Debug 进程，UI 测试会卡住约 60s）。若仅改测试代码，可先 `build-for-testing` 再 `test-without-building`。

`timeUITests` 覆盖：启动显示时钟、`-open-settings` 打开设置、关闭/ESC/点背板关闭（macOS）、⌘, 打开设置、⌘= / ⌘- 字号快捷键、设置打开时时钟仍可见、启动截图附件。

UI 测试启动参数：`-UITesting`（经典弹跳模式、跳过翻页全屏）、可选 `-open-settings`（启动即打开设置）。
