import Foundation

struct TimeZoneProvider {
  /// 获取系统支持的所有时区标识符，并按字母顺序排序
  static var allIdentifiers: [String] {
    TimeZone.knownTimeZoneIdentifiers.sorted()
  }

  /// 获取显示用的格式化字符串，例如 "Tokyo (GMT+9)"
  static func displayString(for identifier: String, date: Date = Date()) -> String {
    let tz = TimeZone(identifier: identifier) ?? .current

    // 1. 提取城市名：将 "Asia/Tokyo" 转换为 "Tokyo"，并处理下划线
    let city =
      identifier.split(separator: "/").last?.replacingOccurrences(of: "_", with: " ")
      ?? identifier

    // 2. 计算 GMT 偏移
    let seconds = tz.secondsFromGMT(for: date)
    let hours = seconds / 3600
    let sign = hours >= 0 ? "+" : ""

    return "\(city) (GMT\(sign)\(hours))"
  }
}
