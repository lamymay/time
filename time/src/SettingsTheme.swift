import SwiftUI

enum SettingsTheme {
  static let panelBackground = Color(white: 0.12)
  static let cardBackground = Color.white.opacity(0.06)
  static let separator = Color.white.opacity(0.1)
  static let secondaryText = Color.white.opacity(0.55)
  static let accent = Color.accentColor

  static var panelCornerRadius: CGFloat {
    #if os(macOS)
      return 16
    #else
      return 20
    #endif
  }
}
