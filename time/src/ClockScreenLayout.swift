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

  /// 自屏幕顶边至弹跳区顶边的距离（pt）；0 = 不避开刘海
  static let notchTopContentInsetKey = "notchTopContentInset"
  static let defaultNotchTopContentInset: CGFloat = 0
  static let notchTopContentInsetRange: ClosedRange<Double> = 0...120

  static func resolvedNotchTopContentInset() -> CGFloat {
    #if os(iOS)
      let stored: Double
      if UserDefaults.standard.object(forKey: notchTopContentInsetKey) != nil {
        stored = UserDefaults.standard.double(forKey: notchTopContentInsetKey)
      } else {
        stored = Double(defaultNotchTopContentInset)
      }
      return CGFloat(
        min(max(stored, notchTopContentInsetRange.lowerBound), notchTopContentInsetRange.upperBound)
      )
    #else
      return 0
    #endif
  }

  /// 刘海机开启避让时，顶距 = 用户设定的屏幕顶边偏移（只应用一次，不与 SwiftUI 安全区叠算）
  static func resolvedTopClockInset(avoidTopSafeAreaOnNotch: Bool) -> CGFloat {
    #if os(iOS)
      guard hasNotchDisplay(), avoidTopSafeAreaOnNotch else { return 0 }
      return resolvedNotchTopContentInset()
    #else
      return 0
    #endif
  }

  #if os(iOS)
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
