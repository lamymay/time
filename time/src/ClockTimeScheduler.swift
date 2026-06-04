import Foundation
import Observation

/// 按下一分钟整点调度；缓存 Calendar 减少分配
@Observable
final class ClockTimeScheduler {
  private(set) var segments = TimeSegments()

  private var format = ClockFormatOptions(
    is24Hour: false,
    padZero: false,
    showAMPM: true,
    ampmSide: "Leading",
    showTimeZoneText: true,
    timeZoneIdentifier: TimeZone.current.identifier,
    displayPrecision: .minute
  )
  private var calendar: Calendar = TimeProvider.makeCalendar(for: TimeZone.current.identifier)
  private var scheduleWorkItem: DispatchWorkItem?
  private var isActive = false

  func setFormat(_ format: ClockFormatOptions) {
    guard self.format != format else { return }
    self.format = format
    calendar = TimeProvider.makeCalendar(for: format.timeZoneIdentifier)
    refreshIfNeeded(at: Date())
    reschedule()
  }

  func setActive(_ active: Bool) {
    guard active != isActive else { return }
    isActive = active
    if active {
      refreshIfNeeded(at: Date())
      reschedule()
    } else {
      cancelSchedule()
    }
  }

  private func refreshIfNeeded(at date: Date) {
    let new = TimeProvider.segments(from: date, format: format, calendar: calendar)
    guard new != segments else { return }
    segments = new
  }

  private func reschedule() {
    cancelSchedule()
    guard isActive else { return }

    let delay = TimeProvider.secondsUntilNextDisplayChange(
      from: Date(), format: format, calendar: calendar)
    let work = DispatchWorkItem { [weak self] in
      guard let self, self.isActive else { return }
      self.refreshIfNeeded(at: Date())
      self.reschedule()
    }
    scheduleWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
  }

  private func cancelSchedule() {
    scheduleWorkItem?.cancel()
    scheduleWorkItem = nil
  }

  deinit {
    cancelSchedule()
  }
}
