import Foundation

/// UI 测试用 accessibilityIdentifier（与 timeUITests 中同名常量保持一致）
enum TimeAccessibilityID {
  static let clockScene = "time.clock.scene"
  static let settingsPanel = "time.settings.panel"
  static let settingsBackdrop = "time.settings.backdrop"
  static let settingsCloseButton = "time.settings.close"
  static let settingsDoneButton = "time.settings.done"
  static let settingsClockPreview = "time.settings.clock_preview"
}

enum AppUITestConfig {
  static var isEnabled: Bool {
    ProcessInfo.processInfo.arguments.contains("-UITesting")
  }

  static var openSettingsOnLaunch: Bool {
    ProcessInfo.processInfo.arguments.contains("-open-settings")
  }

  static var skipFlipLaunchFullscreen: Bool { isEnabled }
}
