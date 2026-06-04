import Foundation
import Observation

/// 按显示精度调度；tick 直推 NativeClockTickTarget，不经过 SwiftUI
@Observable
final class ClockTimeScheduler {
  private(set) var segments = TimeSegments()

  private weak var tickTarget: NativeClockTickTarget?
  private var format = ClockFormatOptions(
    is24Hour: true,
    padZero: false,
    showAMPM: true,
    ampmSide: "Leading",
    showTimeZoneText: false,
    timeZoneIdentifier: TimeZone.current.identifier,
    displayPrecision: .minute
  )
  private var calendar: Calendar = TimeProvider.makeCalendar(for: TimeZone.current.identifier)
  private var scheduleWorkItem: DispatchWorkItem?
  private var isActive = false

  func setTickTarget(_ target: NativeClockTickTarget?) {
    tickTarget = target
    if let target {
      target.applyTick(
        segments: segments,
        changedFields: Set(TimeSegmentField.allCases)
      )
      if isActive { reschedule() }
    } else {
      cancelSchedule()
    }
  }

  func setFormat(_ format: ClockFormatOptions) {
    let formatChanged = self.format != format
    self.format = format
    calendar = TimeProvider.makeCalendar(for: format.timeZoneIdentifier)
    refreshIfNeeded(at: Date(), force: true)
    if isActive, formatChanged || tickTarget != nil {
      reschedule()
    }
  }

  func setActive(_ active: Bool) {
    guard active != isActive else { return }
    isActive = active
    if active {
      refreshIfNeeded(at: Date(), force: true)
      reschedule()
    } else {
      cancelSchedule()
    }
  }

  private func refreshIfNeeded(at date: Date, force: Bool = false) {
    let new = TimeProvider.segments(from: date, format: format, calendar: calendar)
    if !force, new == segments { return }
    let changed = force
      ? Set(TimeSegmentField.allCases)
      : TimeProvider.changedFields(from: segments, to: new)
    segments = new
    tickTarget?.applyTick(segments: new, changedFields: changed)
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
