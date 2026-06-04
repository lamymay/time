import SwiftUI

private struct SettingsCompactLayoutKey: EnvironmentKey {
  static let defaultValue = false
}

extension EnvironmentValues {
  var settingsCompactLayout: Bool {
    get { self[SettingsCompactLayoutKey.self] }
    set { self[SettingsCompactLayoutKey.self] = newValue }
  }
}

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

  static func stackSpacing(compact: Bool) -> CGFloat { compact ? 12 : 22 }
  static func contentPadding(compact: Bool) -> CGFloat { compact ? 12 : 18 }
  static func sectionHeaderFont(compact: Bool) -> Font {
    compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold)
  }
  static func rowLabelFont(compact: Bool) -> Font {
    compact ? .caption : .subheadline
  }
}
