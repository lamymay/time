import Foundation

struct TimeProvider {
  private static let formatter: DateFormatter = {
    let df = DateFormatter()
    df.locale = Locale(identifier: "en_US_POSIX")
    return df
  }()

  // 获取高精度系统时间 (用于 Debug)
  static func getFullSystemTime(from date: Date) -> String {
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    return formatter.string(from: date)
  }

  static func getTimeString(
    from date: Date, is24Hour: Bool, padZero: Bool, timeZoneIdentifier: String
  ) -> String {
    formatter.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
    formatter.dateFormat = is24Hour ? (padZero ? "HH:mm" : "H:mm") : (padZero ? "hh:mm" : "h:mm")
    var result = formatter.string(from: date)
    if is24Hour {
      result = result.replacingOccurrences(of: "[^0-9:]", with: "", options: .regularExpression)
    }
    return result
  }

  static func getAMPMString(from date: Date, is24Hour: Bool, timeZoneIdentifier: String) -> String {
    guard !is24Hour else { return "" }
    formatter.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
    formatter.dateFormat = "a"
    return formatter.string(from: date)
  }

  static func getTimeZoneString(for identifier: String, date: Date) -> String {
    let tz = TimeZone(identifier: identifier) ?? .current
    let city =
      identifier.split(separator: "/").last?.replacingOccurrences(of: "_", with: " ") ?? identifier
    let seconds = tz.secondsFromGMT(for: date)
    let hours = seconds / 3600
    let sign = hours >= 0 ? "+" : ""
    return "\(city) (GMT\(sign)\(hours))"
  }
}
