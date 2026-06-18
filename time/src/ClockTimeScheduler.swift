import Combine
import Foundation

/// 按显示精度调度；tick 直推 NativeClockTickTarget，不经过 SwiftUI
final class ClockTimeScheduler: ObservableObject {
  private(set) var segments = TimeSegments()

  /// 仅设置预览等需要 SwiftUI 读 segments 时开启，避免每秒刷新整棵视图树
  private var publishesSegmentsToSwiftUI = false

  /// 时/分等非秒位变化（如 DVD 拖尾清除）
  var onSignificantSegmentChange: (() -> Void)?

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

  func setPublishesSegmentsToSwiftUI(_ enabled: Bool) {
    guard enabled != publishesSegmentsToSwiftUI else { return }
    publishesSegmentsToSwiftUI = enabled
    if enabled {
      objectWillChange.send()
    }
  }

  func setTickTarget(_ target: NativeClockTickTarget?) {
    let isSameTarget: Bool = {
      if let target, let current = tickTarget {
        return (target as AnyObject) === (current as AnyObject)
      }
      return target == nil && tickTarget == nil
    }()
    guard !isSameTarget else { return }

    tickTarget = target
    if let target {
      target.applyTick(
        segments: segments,
        changedFields: Set(TimeSegmentField.allCases)
      )
    }
    if isActive {
      reschedule()
    }
  }

  func setFormat(_ format: ClockFormatOptions) {
    guard self.format != format else { return }
    self.format = format
    calendar = TimeProvider.makeCalendar(for: format.timeZoneIdentifier)
    refreshIfNeeded(at: Date(), force: true)
    if isActive {
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
    if publishesSegmentsToSwiftUI {
      objectWillChange.send()
    }
    if !changed.isSubset(of: [.secondTens, .secondOnes]) {
      onSignificantSegmentChange?()
    }
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
