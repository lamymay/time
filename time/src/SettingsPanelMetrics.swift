import CoreGraphics

#if canImport(UIKit)
  import UIKit
#endif

/// 设置面板尺寸（iOS 底部 sheet 可收窄、可拖拽调宽）
enum SettingsPanelMetrics {
  static let headerActionButtonSize: CGFloat = 36

  #if os(iOS)
    static var iosSafeAreaTopInset: CGFloat {
      guard let window = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .first(where: { $0.activationState == .foregroundActive })
        .flatMap({ scene in scene.windows.first(where: \.isKeyWindow) })
        ?? UIApplication.shared.connectedScenes
          .compactMap({ $0 as? UIWindowScene })
          .flatMap(\.windows)
          .first(where: \.isKeyWindow)
      else { return 0 }
      return window.safeAreaInsets.top
    }
  #endif
  static let macMinWidth: CGFloat = 360
  static let macIdealWidth: CGFloat = 380

  /// 底部 sheet 较初版收窄 1/5
  static let iosSheetWidthScale: CGFloat = 0.8
  static let iosSheetMin: CGFloat = 208
  static let iosSheetMaxCap: CGFloat = 256
  static let iosSheetHorizontalInset: CGFloat = 20

  /// 全屏设置顶栏时钟预览高度比例
  static let iosExpandedPreviewHeightRatio: CGFloat = 0.34

  static func iosSheetAutoWidth(screen: CGSize) -> CGFloat {
    min(screen.width - iosSheetHorizontalInset * 2, iosSheetMaxCap)
  }

  static func clampIOSSheetWidth(_ width: CGFloat, screen: CGSize) -> CGFloat {
    let maxW = max(iosSheetMin, screen.width - iosSheetHorizontalInset * 2)
    return min(max(width, iosSheetMin), min(maxW, iosSheetMaxCap))
  }

  /// 用户曾拖宽的存盘值按新比例收敛一次
  static func normalizeStoredSheetWidth(_ stored: Double) -> Double {
    guard stored > 0 else { return stored }
    return max(Double(iosSheetMin), stored * Double(iosSheetWidthScale))
  }

  /// `stored <= 0` 表示使用自动宽度
  static func resolvedIOSSheetWidth(stored: Double, screen: CGSize) -> CGFloat {
    guard stored > 0 else { return iosSheetAutoWidth(screen: screen) }
    return clampIOSSheetWidth(CGFloat(normalizeStoredSheetWidth(stored)), screen: screen)
  }
}
