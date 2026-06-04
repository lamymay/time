import Foundation
import SwiftUI

/// 时间 tick 直推原生时钟，避免 @Observable segments 触发 SwiftUI 每 50ms 重绘
protocol NativeClockTickTarget: AnyObject {
  func applyTick(segments: TimeSegments, changedFields: Set<TimeSegmentField>)
  func applyStyle(_ stamp: ClockStyleStamp)
}

/// 样式/颜色（不含 segments）；仅设置变化时经 SwiftUI 更新
struct ClockStyleStamp: Equatable {
  var style: NativeClockStyle
  var precision: TimeDisplayPrecision
  var timeZoneTopGap: CGFloat
  var color: Color
  var showTimeZoneText: Bool
}
