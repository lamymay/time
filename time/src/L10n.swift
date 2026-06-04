import Foundation

/// 应用文案（见 Localizable.xcstrings / InfoPlist.xcstrings）
enum L10n {
  static func text(_ key: String.LocalizationValue) -> String {
    String(localized: key)
  }
}
