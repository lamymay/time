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

  /// 在状态栏基准上再收紧的顶距（pt），使弹跳区更贴近灵动岛下缘
  static let notchTopInsetTighten: CGFloat = 20

  /// 刘海机开启避让时，顶距贴灵动岛 / 刘海下缘（只应用一次，不与 SwiftUI 安全区叠算）
  static func resolvedTopClockInset(avoidTopSafeAreaOnNotch: Bool) -> CGFloat {
    #if os(iOS)
      guard hasNotchDisplay(), avoidTopSafeAreaOnNotch else { return 0 }
      let base = notchAwareTopInset(for: keyWindow)
      return max(0, base - notchTopInsetTighten)
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
