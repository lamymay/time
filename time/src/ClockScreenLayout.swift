import CoreGraphics
import SwiftUI

#if canImport(UIKit)
  import UIKit
#endif

enum ClockScreenLayout {
  /// 刘海 / 灵动岛 iPhone（顶部安全区显著大于传统 20pt 状态栏）
  static func hasNotchDisplay() -> Bool {
    #if os(iOS)
      guard UIDevice.current.userInterfaceIdiom == .phone else { return false }
      return (keyWindow?.safeAreaInsets.top ?? 0) > 20
    #else
      return false
    #endif
  }

  static let notchTopInsetTightenKey = "notchTopInsetTighten"
  static let defaultNotchTopInsetTighten: CGFloat = 20
  static let notchTopInsetTightenRange: ClosedRange<Double> = 0...100

  static func resolvedTopInsetTighten() -> CGFloat {
    #if os(iOS)
      guard UserDefaults.standard.object(forKey: notchTopInsetTightenKey) != nil else {
        return defaultNotchTopInsetTighten
      }
      let stored = UserDefaults.standard.double(forKey: notchTopInsetTightenKey)
      return CGFloat(
        min(max(stored, notchTopInsetTightenRange.lowerBound), notchTopInsetTightenRange.upperBound)
      )
    #else
      return 0
    #endif
  }

  /// 刘海机开启避让时，顶距贴灵动岛 / 刘海下缘（只应用一次，不与 SwiftUI 安全区叠算）
  static func resolvedTopClockInset(avoidTopSafeAreaOnNotch: Bool) -> CGFloat {
    #if os(iOS)
      guard hasNotchDisplay(), avoidTopSafeAreaOnNotch else { return 0 }
      let base = notchAwareTopInset(for: keyWindow)
      return max(0, base - resolvedTopInsetTighten())
    #else
      return 0
    #endif
  }

  #if os(iOS)
    /// `safeAreaInsets.top` 常含灵动岛下额外留白；刘海机改用状态栏高度贴齐下缘
    private static func notchAwareTopInset(for window: UIWindow?) -> CGFloat {
      guard let window else { return 0 }
      let safeTop = window.safeAreaInsets.top
      guard safeTop > 0 else { return 0 }
      if let statusH = window.windowScene?.statusBarManager?.statusBarFrame.height,
        statusH > 20
      {
        return statusH
      }
      return safeTop
    }

    private static var keyWindow: UIWindow? {
      UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first { $0.activationState == .foregroundActive }
        .flatMap { scene in scene.windows.first { $0.isKeyWindow } }
        ?? UIApplication.shared.connectedScenes
          .compactMap { $0 as? UIWindowScene }
          .flatMap(\.windows)
          .first { $0.isKeyWindow }
    }
  #endif

  /// iOS 横屏：右侧贴边设置栏；macOS / iPad 宽屏：侧边栏
  static func usesSideSettingsPanel(screen: CGSize) -> Bool {
    #if os(iOS)
      return screen.width > screen.height
    #else
      return screen.width > 600
    #endif
  }

  #if os(iOS)
    /// 竖屏底部 sheet 高度比例
    static let iosPortraitSheetHeightRatio: CGFloat = 2 / 5

    static func iosPortraitSheetHeight(screen: CGSize) -> CGFloat {
      max(120, screen.height * iosPortraitSheetHeightRatio)
    }
  #endif

  static func sidePanelWidth(screen: CGSize) -> CGFloat {
    usesSideSettingsPanel(screen: screen) ? 300 : screen.width * 0.7
  }

  static func settingsPanelWidth(screen: CGSize) -> CGFloat {
    usesSideSettingsPanel(screen: screen) ? min(400, screen.width * 0.38) : screen.width
  }
}
