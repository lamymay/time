import Foundation

/// 主时钟展示样式
enum ClockDisplayStyle: String, CaseIterable, Identifiable, Codable {
  case classic
  case flip

  var id: String { rawValue }

  var label: String {
    switch self {
    case .classic: L10n.text("style.classic")
    case .flip: L10n.text("style.flip")
    }
  }

  var subtitle: String {
    switch self {
    case .classic: L10n.text("style.classic_subtitle")
    case .flip: L10n.text("style.flip_subtitle")
    }
  }
}
