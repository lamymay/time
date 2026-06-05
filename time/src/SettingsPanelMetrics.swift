import CoreGraphics

/// 设置面板尺寸（iOS 底部 sheet 可收窄、可拖拽调宽）
enum SettingsPanelMetrics {
  static let macMinWidth: CGFloat = 360
  static let macIdealWidth: CGFloat = 380

  /// 底部 sheet 较初版收窄 1/5
  static let iosSheetWidthScale: CGFloat = 0.8
  static let iosSheetMin: CGFloat = 208
  static let iosSheetMaxCap: CGFloat = 256
  static let iosSheetHorizontalInset: CGFloat = 20

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
