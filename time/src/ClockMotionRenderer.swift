import CoreGraphics
import SwiftUI

/// 弹跳位移直达原生视图，不经过 @Observable，避免每帧刷新 SwiftUI
protocol ClockMotionRenderer: AnyObject {
  /// 时钟中心在容器坐标系中的位置（与 screenSize 同系）
  func setClockCenter(_ center: CGPoint)
  /// 碰撞变色直推原生层，避免 styleStamp 变化触发整表重布局
  func setClockDisplayColor(_ color: Color)
}
