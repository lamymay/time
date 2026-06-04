import SwiftUI

#if canImport(AppKit)
  import AppKit
#else
  import UIKit
#endif

/// 翻页灰底面板上的数字色：过暗时自动提亮，避免与 #46464C 融在一起
enum FlipReadableColor {
  static func digitColor(preferred: Color, cardFace: Color) -> Color {
    let textL = preferred.relativeLuminance
    let faceL = cardFace.relativeLuminance
    if abs(textL - faceL) >= 0.32 {
      return preferred
    }
    if faceL < 0.5 {
      return preferred.boostedBrightness(floor: 0.78, minSaturation: 0.45)
    }
    return preferred.boostedBrightness(ceiling: 0.28, forceDark: true)
  }
}

private extension Color {
  var relativeLuminance: Double {
    guard let (r, g, b) = sRGBComponents else { return 0 }
    func linearize(_ c: Double) -> Double {
      c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
    let lr = linearize(r)
    let lg = linearize(g)
    let lb = linearize(b)
    return 0.2126 * lr + 0.7152 * lg + 0.0722 * lb
  }

  func boostedBrightness(
    floor: Double = 0,
    ceiling: Double = 1,
    minSaturation: Double = 0,
    forceDark: Bool = false
  ) -> Color {
    guard let (h, s0, bright0, _) = hsbaComponents else { return self }
    if forceDark {
      let bright = min(bright0, ceiling)
      return Color(hue: h, saturation: s0, brightness: bright)
    }
    let bright = max(bright0, floor)
    let s = max(s0, minSaturation)
    return Color(hue: h, saturation: min(s, 1), brightness: min(bright, 1))
  }

  private var hsbaComponents: (h: Double, s: Double, b: Double, a: Double)? {
    #if os(macOS)
      let ns = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
      var hue: CGFloat = 0
      var s: CGFloat = 0
      var b: CGFloat = 0
      var a: CGFloat = 0
      ns.getHue(&hue, saturation: &s, brightness: &b, alpha: &a)
      return (Double(hue), Double(s), Double(b), Double(a))
    #else
      var hue: CGFloat = 0
      var s: CGFloat = 0
      var b: CGFloat = 0
      var a: CGFloat = 0
      UIColor(self).getHue(&hue, saturation: &s, brightness: &b, alpha: &a)
      return (Double(hue), Double(s), Double(b), Double(a))
    #endif
  }
}
