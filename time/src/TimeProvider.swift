import Foundation

struct TimeSegments: Equatable {
  var leadingAMPM: String = ""
  var hourTens: String = ""
  var hourOnes: String = ""
  var minuteTens: String = ""
  var minuteOnes: String = ""
  var secondTens: String = ""
  var secondOnes: String = ""
  var trailingAMPM: String = ""
  var timeZoneLabel: String = ""
}

enum TimeSegmentField: String, CaseIterable {
  case leadingAMPM
  case hourTens
  case hourOnes
  case minuteTens
  case minuteOnes
  case secondTens
  case secondOnes
  case trailingAMPM
  case timeZoneLabel
}

struct ClockFormatOptions: Equatable {
  var is24Hour: Bool
  var padZero: Bool
  var showAMPM: Bool
  var ampmSide: String
  var showTimeZoneText: Bool
  var timeZoneIdentifier: String
  var displayPrecision: TimeDisplayPrecision

  var effectiveShowAMPM: Bool { is24Hour ? false : showAMPM }
}

struct TimeProvider {
  static func makeCalendar(for timeZoneIdentifier: String) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
    return calendar
  }

  static func segments(from date: Date, format: ClockFormatOptions) -> TimeSegments {
    segments(from: date, format: format, calendar: makeCalendar(for: format.timeZoneIdentifier))
  }

  static func segments(from date: Date, format: ClockFormatOptions, calendar: Calendar) -> TimeSegments {
    var hour = calendar.component(.hour, from: date)
    let minute = calendar.component(.minute, from: date)
    var ampm = ""

    if !format.is24Hour {
      ampm = hour >= 12 ? "PM" : "AM"
      hour = hour % 12
      if hour == 0 { hour = 12 }
    }

    let hourText: String = {
      if format.padZero {
        return String(format: "%02d", hour)
      }
      return String(hour)
    }()

    let (hourTens, hourOnes) = splitDisplayDigits(hourText)
    let minuteText = String(format: "%02d", minute)

    let leading = format.ampmSide == "Leading" && format.effectiveShowAMPM ? ampm : ""
    let trailing = format.ampmSide == "Trailing" && format.effectiveShowAMPM ? ampm : ""

    var secondTens = ""
    var secondOnes = ""
    if format.displayPrecision.includesSeconds {
      let secondText = String(format: "%02d", calendar.component(.second, from: date))
      secondTens = String(secondText.prefix(1))
      secondOnes = String(secondText.suffix(1))
    }

    var result = TimeSegments(
      leadingAMPM: leading,
      hourTens: hourTens,
      hourOnes: hourOnes,
      minuteTens: String(minuteText.prefix(1)),
      minuteOnes: String(minuteText.suffix(1)),
      secondTens: secondTens,
      secondOnes: secondOnes,
      trailingAMPM: trailing,
      timeZoneLabel: ""
    )

    if format.showTimeZoneText {
      result.timeZoneLabel = timeZoneLabel(for: format.timeZoneIdentifier, date: date)
    }
    return result
  }

  static func nextDisplayChangeBoundary(
    after date: Date, format: ClockFormatOptions, calendar: Calendar
  ) -> Date {
    switch format.displayPrecision {
    case .minute:
      return nextMinuteBoundary(after: date, calendar: calendar)
    case .second:
      return nextSecondBoundary(after: date, calendar: calendar)
    }
  }

  static func nextMinuteBoundary(after date: Date, timeZoneIdentifier: String) -> Date {
    nextMinuteBoundary(after: date, calendar: makeCalendar(for: timeZoneIdentifier))
  }

  static func nextMinuteBoundary(after date: Date, calendar: Calendar) -> Date {
    let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    guard let startOfMinute = calendar.date(from: parts),
      let next = calendar.date(byAdding: .minute, value: 1, to: startOfMinute)
    else {
      return date.addingTimeInterval(60)
    }
    return next
  }

  static func nextSecondBoundary(after date: Date, calendar: Calendar) -> Date {
    let parts = calendar.dateComponents(
      [.year, .month, .day, .hour, .minute, .second], from: date)
    guard let startOfSecond = calendar.date(from: parts),
      let next = calendar.date(byAdding: .second, value: 1, to: startOfSecond)
    else {
      return date.addingTimeInterval(1)
    }
    return next
  }

  static func secondsUntilNextDisplayChange(from date: Date, format: ClockFormatOptions) -> TimeInterval {
    secondsUntilNextDisplayChange(
      from: date, format: format, calendar: makeCalendar(for: format.timeZoneIdentifier))
  }

  static func secondsUntilNextDisplayChange(
    from date: Date, format: ClockFormatOptions, calendar: Calendar
  ) -> TimeInterval {
    let next = nextDisplayChangeBoundary(after: date, format: format, calendar: calendar)
    return max(next.timeIntervalSince(date), 0.001)
  }

  static func fieldsChangingAtNextTick(
    from date: Date, format: ClockFormatOptions
  ) -> Set<TimeSegmentField> {
    let calendar = makeCalendar(for: format.timeZoneIdentifier)
    let current = segments(from: date, format: format, calendar: calendar)
    let nextDate = nextDisplayChangeBoundary(after: date, format: format, calendar: calendar)
    let next = segments(from: nextDate, format: format, calendar: calendar)
    return changedFields(from: current, to: next)
  }

  /// 兼容旧测试名
  static func fieldsChangingAtNextMinute(
    from date: Date, format: ClockFormatOptions
  ) -> Set<TimeSegmentField> {
    fieldsChangingAtNextTick(from: date, format: format)
  }

  static func changedFields(from old: TimeSegments, to new: TimeSegments) -> Set<TimeSegmentField> {
    var changed = Set<TimeSegmentField>()
    if old.leadingAMPM != new.leadingAMPM { changed.insert(.leadingAMPM) }
    if old.hourTens != new.hourTens { changed.insert(.hourTens) }
    if old.hourOnes != new.hourOnes { changed.insert(.hourOnes) }
    if old.minuteTens != new.minuteTens { changed.insert(.minuteTens) }
    if old.minuteOnes != new.minuteOnes { changed.insert(.minuteOnes) }
    if old.secondTens != new.secondTens { changed.insert(.secondTens) }
    if old.secondOnes != new.secondOnes { changed.insert(.secondOnes) }
    if old.trailingAMPM != new.trailingAMPM { changed.insert(.trailingAMPM) }
    if old.timeZoneLabel != new.timeZoneLabel { changed.insert(.timeZoneLabel) }
    return changed
  }

  /// 使用预加载的 formatter 格式化系统时间（精度由设置决定）
  static func formatSystemTime(from date: Date, precision: TimeDisplayPrecision) -> String {
    SystemTimeFormatters.string(from: date, precision: precision)
  }

  private static func splitDisplayDigits(_ text: String) -> (String, String) {
    guard text.count > 1 else { return ("", text) }
    return (String(text.prefix(1)), String(text.suffix(1)))
  }

  private static func timeZoneLabel(for identifier: String, date: Date) -> String {
    let tz = TimeZone(identifier: identifier) ?? .current
    let city =
      identifier.split(separator: "/").last?.replacingOccurrences(of: "_", with: " ") ?? identifier
    let seconds = tz.secondsFromGMT(for: date)
    let hours = seconds / 3600
    let sign = hours >= 0 ? "+" : ""
    return "\(city) (GMT\(sign)\(hours))"
  }
}
