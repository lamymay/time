import Foundation

/// 翻页时钟排版：三等分逐位 / 双板压缩秒
enum FlipClockFormat: String, CaseIterable, Identifiable, Codable {
  case tripleEqual
  case compactPanels

  var id: String { rawValue }

  var label: String {
    switch self {
    case .tripleEqual: L10n.text("flip.format.triple_equal")
    case .compactPanels: L10n.text("flip.format.compact_panels")
    }
  }

  var subtitle: String {
    switch self {
    case .tripleEqual: L10n.text("flip.format.triple_equal_subtitle")
    case .compactPanels: L10n.text("flip.format.compact_panels_subtitle")
    }
  }

  static func resolved(fromRaw raw: String) -> FlipClockFormat {
    FlipClockFormat(rawValue: raw) ?? .compactPanels
  }
}
