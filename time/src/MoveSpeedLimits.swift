import Foundation

enum MoveSpeedLimits {
  /// 滑条下限：0 表示固定位置不移动
  static let min: Double = 0
  /// 滑条上限（约为旧版 100% 的 2.5 倍）
  static let max: Double = 2.5
  /// 速度 1.0 时约 100 像素/秒
  static let pixelsPerSecondFactor: Double = 100

  static func displayLabel(for speed: Double) -> String {
    if speed < 0.005 { return L10n.text("speed.still") }
    return "\(Int(round(speed * 100)))%"
  }

  /// 屏保常驻：慢速 6fps，满速约 9fps
  static func motionInterval(for speed: Double) -> TimeInterval {
    guard speed > 0 else { return .infinity }
    let t = Swift.min(Swift.max(speed / max, 0), 1)
    let fps = 6 + t * 3
    return 1.0 / fps
  }
}
