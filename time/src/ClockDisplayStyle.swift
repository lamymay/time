import Foundation

/// 主时钟展示样式
enum ClockDisplayStyle: String, CaseIterable, Identifiable, Codable {
  case classic
  case flip

  var id: String { rawValue }

  var label: String {
    switch self {
    case .classic: return "经典"
    case .flip: return "翻页"
    }
  }

  var subtitle: String {
    switch self {
    case .classic: return "可弹跳移动"
    case .flip: return "全屏居中 · HTC 翻页"
    }
  }
}
