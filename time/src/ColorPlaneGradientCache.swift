import SwiftUI

/// 色条渐变预计算，避免设置面板滚动时重复分配 21×Color
enum ColorPlaneGradientCache {
  private static let huePlaneOrigin: Double = 1.0 / 6.0
  private static var hueStopsBySaturation: [Int: [Color]] = [:]

  static func hueStops(saturation: Double) -> [Color] {
    let key = Int((saturation * 100).rounded())
    if let cached = hueStopsBySaturation[key] { return cached }
    let stops = stride(from: 0.0, through: 1.0, by: 0.1).map { planeHue in
      let hue = (planeHue + huePlaneOrigin).truncatingRemainder(dividingBy: 1)
      return Color(hue: hue, saturation: saturation, brightness: 1)
    }
    hueStopsBySaturation[key] = stops
    return stops
  }
}
