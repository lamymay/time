import Foundation

/// 时间显示精度（设置项）；对应预加载的 DateFormatter
enum TimeDisplayPrecision: String, CaseIterable, Identifiable, Codable {
  case minute
  case second
  case millisecond

  var id: String { rawValue }

  var label: String {
    switch self {
    case .minute: return "分"
    case .second: return "秒"
    case .millisecond: return "毫秒"
    }
  }

  /// Debug / 系统时间完整格式（formatter 预加载，主线程使用）
  var systemDateFormat: String {
    switch self {
    case .minute: return "yyyy-MM-dd HH:mm"
    case .second: return "yyyy-MM-dd HH:mm:ss"
    case .millisecond: return "yyyy-MM-dd HH:mm:ss.SSS"
    }
  }

  var includesSeconds: Bool {
    self != .minute
  }

  var includesMilliseconds: Bool {
    self == .millisecond
  }

  /// Debug 叠层 TimelineView 刷新间隔
  var debugTimelineInterval: TimeInterval {
    switch self {
    case .minute: return 1
    case .second: return 1
    case .millisecond: return 0.05
    }
  }
}

/// 预加载全部精度的 DateFormatter（无锁，主线程 / OS 时钟刷新）
enum SystemTimeFormatters {
  private static let posixLocale = Locale(identifier: "en_US_POSIX")

  private static func makeFormatter(dateFormat: String) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = posixLocale
    formatter.dateFormat = dateFormat
    return formatter
  }

  static let minute: DateFormatter = makeFormatter(
    dateFormat: TimeDisplayPrecision.minute.systemDateFormat)
  static let second: DateFormatter = makeFormatter(
    dateFormat: TimeDisplayPrecision.second.systemDateFormat)
  static let millisecond: DateFormatter = makeFormatter(
    dateFormat: TimeDisplayPrecision.millisecond.systemDateFormat)

  static func string(from date: Date, precision: TimeDisplayPrecision) -> String {
    switch precision {
    case .minute: minute.string(from: date)
    case .second: second.string(from: date)
    case .millisecond: millisecond.string(from: date)
    }
  }
}
