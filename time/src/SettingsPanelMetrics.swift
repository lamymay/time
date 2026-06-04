import CoreGraphics

/// 设置面板尺寸（iOS 底部 sheet 可收窄、可拖拽调宽）
enum SettingsPanelMetrics {
  static let macMinWidth: CGFloat = 360
  static let macIdealWidth: CGFloat = 380

  static let iosSheetMin: CGFloat = 280
  static let iosSheetMaxCap: CGFloat = 420
  static let iosSheetHorizontalInset: CGFloat = 16

  static func iosSheetAutoWidth(screen: CGSize) -> CGFloat {
    min(screen.width - iosSheetHorizontalInset * 2, iosSheetMaxCap)
  }

  static func clampIOSSheetWidth(_ width: CGFloat, screen: CGSize) -> CGFloat {
    let maxW = max(iosSheetMin, screen.width - iosSheetHorizontalInset * 2)
    return min(max(width, iosSheetMin), min(maxW, iosSheetMaxCap))
  }

  /// `stored <= 0` 表示使用自动宽度
  static func resolvedIOSSheetWidth(stored: Double, screen: CGSize) -> CGFloat {
    guard stored > 0 else { return iosSheetAutoWidth(screen: screen) }
    return clampIOSSheetWidth(CGFloat(stored), screen: screen)
  }
}
