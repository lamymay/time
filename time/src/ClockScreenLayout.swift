import CoreGraphics

#if canImport(UIKit)
  import UIKit
#endif

enum ClockScreenLayout {
  /// iPhone 横屏宽度常 > 600，但仍应按手机布局；仅 iPad 宽屏用侧边设置栏
  static func usesSideSettingsPanel(screen: CGSize) -> Bool {
    #if os(iOS)
      return UIDevice.current.userInterfaceIdiom == .pad && screen.width > 600
    #else
      return screen.width > 600
    #endif
  }

  static func sidePanelWidth(screen: CGSize) -> CGFloat {
    usesSideSettingsPanel(screen: screen) ? 300 : screen.width * 0.7
  }

  static func settingsPanelWidth(screen: CGSize) -> CGFloat {
    usesSideSettingsPanel(screen: screen) ? min(400, screen.width * 0.38) : screen.width
  }
}
