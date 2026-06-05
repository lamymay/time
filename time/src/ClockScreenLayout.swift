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
      return keyWindowSafeAreaInsets.top > 20
    #else
      return false
    #endif
  }

  /// 时钟层应忽略的安全区边：默认仅左/右/底；刘海机开启「避让顶部」时保留顶部
  static func clockBleedEdges(avoidTopSafeAreaOnNotch: Bool) -> Edge.Set {
    #if os(iOS)
      if hasNotchDisplay(), avoidTopSafeAreaOnNotch {
        return [.leading, .trailing, .bottom]
      }
      return .all
    #else
      return .all
    #endif
  }

  #if os(iOS)
    private static var keyWindowSafeAreaInsets: UIEdgeInsets {
      UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap(\.windows)
        .first { $0.isKeyWindow }?
        .safeAreaInsets ?? .zero
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
