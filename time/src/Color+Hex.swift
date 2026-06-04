import SwiftUI

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
