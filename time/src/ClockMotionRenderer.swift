import CoreGraphics

/// 弹跳位移直达原生视图，不经过 @Observable，避免每帧刷新 SwiftUI
protocol ClockMotionRenderer: AnyObject {
  func setTranslation(_ offset: CGSize)
}
