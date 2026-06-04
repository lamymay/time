import SwiftUI
#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif

extension Color {
  init(hex: String) {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)
    let r, g, b: Double
    switch hex.count {
    case 6:
      r = Double((int >> 16) & 0xFF) / 255
      g = Double((int >> 8) & 0xFF) / 255
      b = Double(int & 0xFF) / 255
    default:
      r = 0
      g = 0
      b = 0
    }
    self.init(red: r, green: g, blue: b)
  }

  init(clockHue hue: Double) {
    self.init(
      hue: hue,
      saturation: 0.82,
      brightness: 0.95
    )
  }

  var rgbHexString: String {
    guard let (r, g, b) = sRGBComponents else {
      return ClockColorCodec.defaultHex
    }
    return String(
      format: "#%02X%02X%02X",
      Int((r * 255).rounded()),
      Int((g * 255).rounded()),
      Int((b * 255).rounded())
    )
  }

  /// 色条上的位置 0…1；低饱和度时按 RGB 估一个色相
  var clockHuePosition: Double { pickerHue }

  var pickerHue: Double {
    if let h = sRGBHue, sRGBSaturation > 0.06 {
      return h
    }
    return estimatedHueFromRGB
  }

  var pickerBrightness: Double {
    if let b = sRGBBrightness { return b }
    guard let (r, g, b) = sRGBComponents else { return 0.5 }
    return max(r, g, b)
  }

  var pickerSaturation: Double {
    sRGBSaturation
  }

  /// 近似判断浅色背景（自定义 hex 时用）
  var isLightBackground: Bool {
    guard let (r, g, b) = sRGBComponents else { return false }
    return (0.299 * r + 0.587 * g + 0.114 * b) > 0.55
  }

  private var estimatedHueFromRGB: Double {
    guard let (r, g, b) = sRGBComponents else { return 0.52 }
    let maxC = max(r, g, b)
    let minC = min(r, g, b)
    if maxC - minC < 0.02 { return 0.52 }
    var h: Double = 0
    let d = maxC - minC
    if maxC == r {
      h = (g - b) / d + (g < b ? 6 : 0)
    } else if maxC == g {
      h = (b - r) / d + 2
    } else {
      h = (r - g) / d + 4
    }
    return (h / 6).truncatingRemainder(dividingBy: 1)
  }

  private var sRGBBrightness: Double? {
    #if os(macOS)
    guard let c = NSColor(self).usingColorSpace(.sRGB) else { return nil }
    var h: CGFloat = 0
    var s: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
    return Double(b)
    #else
    var h: CGFloat = 0
    var s: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    guard UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return nil }
    return Double(b)
    #endif
  }

  var sRGBComponents: (r: Double, g: Double, b: Double)? {
    #if os(macOS)
    guard let c = NSColor(self).usingColorSpace(.sRGB) else { return nil }
    return (Double(c.redComponent), Double(c.greenComponent), Double(c.blueComponent))
    #else
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    guard UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
    return (Double(r), Double(g), Double(b))
    #endif
  }

  private var sRGBHue: Double? {
    #if os(macOS)
    guard let c = NSColor(self).usingColorSpace(.sRGB) else { return nil }
    var h: CGFloat = 0
    var s: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
    return Double(h)
    #else
    var h: CGFloat = 0
    var s: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    guard UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return nil }
    return Double(h)
    #endif
  }

  private var sRGBSaturation: Double {
    #if os(macOS)
    guard let c = NSColor(self).usingColorSpace(.sRGB) else { return 0 }
    var h: CGFloat = 0
    var s: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
    return Double(s)
    #else
    var h: CGFloat = 0
    var s: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    guard UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return 0 }
    return Double(s)
    #endif
  }
}

enum ColorPickerCodec {
  static let defaultHex = "#000000"
  static let defaultSaturation = 0.88

  static func hex(hue: Double, brightness: Double, saturation: Double = defaultSaturation) -> String {
    Color(hue: hue, saturation: saturation, brightness: brightness).rgbHexString
  }

  static func normalizedHex(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.hasPrefix("#"), trimmed.count == 7 else { return defaultHex }
    return trimmed.uppercased()
  }
}

enum ClockColorCodec {
  static let defaultHex = "#6EEBD8"

  static func normalizedHex(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.hasPrefix("#"), trimmed.count == 7 else { return defaultHex }
    return trimmed.uppercased()
  }
}

enum BackgroundColorPreset: String, CaseIterable, Identifiable {
  case black = "#000000"
  case darkGray = "#1A1A1A"
  case navy = "#0A0A1A"
  case darkGreen = "#0A1A0A"

  case white = "#FFFFFF"
  case lightGray = "#F2F2F7"
  case cream = "#FAF6EE"
  case lightBlue = "#E8F4FC"

  var id: String { rawValue }

  var label: String {
    switch self {
    case .black: L10n.text("bg.black")
    case .darkGray: L10n.text("bg.dark_gray")
    case .navy: L10n.text("bg.navy")
    case .darkGreen: L10n.text("bg.dark_green")
    case .white: L10n.text("bg.white")
    case .lightGray: L10n.text("bg.light_gray")
    case .cream: L10n.text("bg.cream")
    case .lightBlue: L10n.text("bg.light_blue")
    }
  }

  var color: Color { Color(hex: rawValue) }

  var isLight: Bool {
    switch self {
    case .white, .lightGray, .cream, .lightBlue: true
    default: false
    }
  }

  /// 与背景对比清晰的默认时钟颜色
  var defaultClockColor: Color {
    if isLight {
      return Color(hex: "#0A6B5C")
    }
    return Color(hex: "#6EEBD8")
  }

  static var darkPresets: [BackgroundColorPreset] {
    allCases.filter { !$0.isLight }
  }

  static var lightPresets: [BackgroundColorPreset] {
    allCases.filter(\.isLight)
  }

  static func from(hex: String) -> BackgroundColorPreset? {
    BackgroundColorPreset(rawValue: hex)
  }

  static func randomCollisionColor(lightBackground: Bool) -> Color {
    if lightBackground {
      return Color(
        red: .random(in: 0.05...0.45),
        green: .random(in: 0.15...0.5),
        blue: .random(in: 0.1...0.45)
      )
    }
    return Color(
      red: .random(in: 0.4...1),
      green: .random(in: 0.4...1),
      blue: .random(in: 0.4...1)
    )
  }
}

/// 翻页时钟默认色
enum ClockColorPreset: String {
  case mint = "#6EEBD8"

  var color: Color { Color(hex: rawValue) }
}
