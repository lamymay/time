import Combine
import CoreGraphics
import Foundation

/// 屏保烧屏优化：每分钟约 1px 的 DVD 式贴边漂移（翻页 / 弹跳共用）
final class OledPixelShiftEngine: ObservableObject {
  static let stepPixels: CGFloat = 1
  static let tickInterval: TimeInterval = 60

  @Published private(set) var offset: CGSize = .zero

  private var direction = CGVector(dx: 1, dy: 1)
  private var screenSize: CGSize = .zero
  private var contentSize: CGSize = .zero
  private var isEnabled = false
  private var isActive = false
  private var didSeedDirection = false
  private var timer: DispatchSourceTimer?

  func setEnabled(_ enabled: Bool) {
    guard enabled != isEnabled else { return }
    isEnabled = enabled
    if enabled {
      ensureDirection()
      restartTimerIfNeeded()
    } else {
      stopTimer()
      offset = .zero
    }
  }

  func setActive(_ active: Bool) {
    guard active != isActive else { return }
    isActive = active
    restartTimerIfNeeded()
  }

  func setScreenSize(_ size: CGSize) {
    screenSize = size
    clampOffsetToBounds()
  }

  func setContentSize(_ size: CGSize) {
    contentSize = size
    clampOffsetToBounds()
  }

  // MARK: - Timer

  private func restartTimerIfNeeded() {
    guard isEnabled, isActive else {
      stopTimer()
      return
    }
    guard timer == nil else { return }
    ensureDirection()
    let source = DispatchSource.makeTimerSource(queue: .main)
    source.schedule(
      deadline: .now() + Self.tickInterval,
      repeating: Self.tickInterval,
      leeway: .seconds(2)
    )
    source.setEventHandler { [weak self] in
      self?.stepOnce()
    }
    source.resume()
    timer = source
  }

  private func stopTimer() {
    timer?.cancel()
    timer = nil
  }

  private func ensureDirection() {
    guard !didSeedDirection else { return }
    didSeedDirection = true
    direction = CGVector(
      dx: Bool.random() ? 1 : -1,
      dy: Bool.random() ? 1 : -1
    )
  }

  // MARK: - Physics

  private var maxOffsetX: CGFloat {
    guard screenSize.width > 0, contentSize.width > 0 else { return 0 }
    return max(0, (screenSize.width - contentSize.width) / 2)
  }

  private var maxOffsetY: CGFloat {
    guard screenSize.height > 0, contentSize.height > 0 else { return 0 }
    return max(0, (screenSize.height - contentSize.height) / 2)
  }

  private func stepOnce() {
    guard isEnabled, isActive else { return }
    guard maxOffsetX > 0 || maxOffsetY > 0 else { return }

    var ox = offset.width + direction.dx * Self.stepPixels
    var oy = offset.height + direction.dy * Self.stepPixels

    if maxOffsetX > 0 {
      if ox <= -maxOffsetX {
        ox = -maxOffsetX
        direction.dx = abs(direction.dx > 0 ? direction.dx : 1)
      } else if ox >= maxOffsetX {
        ox = maxOffsetX
        direction.dx = -abs(direction.dx < 0 ? direction.dx : 1)
      }
    } else {
      ox = 0
      direction.dx = 0
    }

    if maxOffsetY > 0 {
      if oy <= -maxOffsetY {
        oy = -maxOffsetY
        direction.dy = abs(direction.dy > 0 ? direction.dy : 1)
      } else if oy >= maxOffsetY {
        oy = maxOffsetY
        direction.dy = -abs(direction.dy < 0 ? direction.dy : 1)
      }
    } else {
      oy = 0
      direction.dy = 0
    }

    if direction.dx == 0, direction.dy == 0 {
      direction = CGVector(dx: 1, dy: 1)
    }

    let next = CGSize(width: ox, height: oy)
    if next != offset {
      offset = next
    }
  }

  private func clampOffsetToBounds() {
    guard isEnabled else { return }
    let mx = maxOffsetX
    let my = maxOffsetY
    guard mx > 0 || my > 0 else {
      offset = .zero
      return
    }
    offset = CGSize(
      width: min(max(offset.width, -mx), mx),
      height: min(max(offset.height, -my), my)
    )
  }

  deinit {
    stopTimer()
  }
}
