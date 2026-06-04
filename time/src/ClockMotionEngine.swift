import Foundation
import Observation
import SwiftUI

/// 屏保级弹跳物理：位移走 ClockMotionRenderer，仅碰撞变色触发 SwiftUI
@Observable
final class ClockMotionEngine {
  var position: CGPoint?
  var clockColor: Color = BackgroundColorPreset.black.defaultClockColor
  var totalSize: CGSize = .zero
  var trailSamples: [MotionTrailSample] = []

  private var direction = CGVector(dx: 1, dy: 1)
  private var motionTimer: DispatchSourceTimer?
  private var lastTickDate: Date?
  private var screenSize: CGSize = .zero
  private var screenCenter: CGPoint = .zero
  private var moveSpeed: Double = 0.09
  private var isMotionActive = false
  private var isPaused = false
  private var lightBackground = false
  private var userClockColorHex: String?

  private weak var renderer: ClockMotionRenderer?
  private var lastRenderedOffset: CGSize?

  func setRenderer(_ renderer: ClockMotionRenderer?) {
    self.renderer = renderer
    if renderer != nil {
      pushOffsetToRenderer()
      renderer?.setClockDisplayColor(clockColor)
    }
  }

  func applyBackground(hex: String) {
    let preset = BackgroundColorPreset.from(hex: hex)
    let bg = Color(hex: ColorPickerCodec.normalizedHex(hex))
    lightBackground = preset?.isLight ?? bg.isLightBackground
    applyResolvedClockColor(preset: preset, background: bg)
  }

  func applyUserClockColor(hex: String) {
    userClockColorHex = ColorPickerCodec.normalizedHex(hex)
    clockColor = Color(hex: userClockColorHex ?? hex)
    renderer?.setClockDisplayColor(clockColor)
  }

  private func applyResolvedClockColor(preset: BackgroundColorPreset?, background: Color) {
    if let userClockColorHex {
      clockColor = Color(hex: userClockColorHex)
      return
    }
    clockColor = preset?.defaultClockColor ?? (background.isLightBackground
      ? Color(hex: "#0A6B5C")
      : Color(hex: "#6EEBD8"))
  }

  func setScreenSize(_ size: CGSize) {
    guard size.width > 1, size.height > 1 else { return }
    let changed =
      abs(screenSize.width - size.width) > 0.5 || abs(screenSize.height - size.height) > 0.5
    screenSize = size
    screenCenter = CGPoint(x: size.width / 2, y: size.height / 2)
    if position == nil {
      position = screenCenter
    } else if changed {
      position = clampedPosition(position ?? screenCenter)
    }
    pushOffsetToRenderer()
  }

  private func clampedPosition(_ point: CGPoint) -> CGPoint {
    guard totalSize.width > 0, totalSize.height > 0 else { return screenCenter }
    let minX = totalSize.width / 2
    let maxX = screenSize.width - totalSize.width / 2
    let minY = totalSize.height / 2
    let maxY = screenSize.height - totalSize.height / 2
    return CGPoint(
      x: min(max(point.x, minX), maxX),
      y: min(max(point.y, minY), maxY)
    )
  }

  /// 原生时钟完成测量后，确保定时器与位移已就绪
  func ensureBounceReady() {
    if position == nil {
      position = screenCenter
    }
    pushOffsetToRenderer()
    restartMotionTimerIfNeeded()
  }

  func setMoveSpeed(_ speed: Double) {
    moveSpeed = min(max(speed, MoveSpeedLimits.min), MoveSpeedLimits.max)
    if moveSpeed <= 0 {
      stopMotionTimer()
    } else {
      restartMotionTimerIfNeeded()
    }
  }

  func setPaused(_ paused: Bool) {
    guard paused != isPaused else { return }
    isPaused = paused
    restartMotionTimerIfNeeded()
  }

  func setMotionActive(_ active: Bool) {
    guard active != isMotionActive else { return }
    isMotionActive = active
    if !active { clearTrail() }
    restartMotionTimerIfNeeded()
  }

  private func restartMotionTimerIfNeeded() {
    if isMotionActive, !isPaused, moveSpeed > 0 {
      startMotionTimer()
    } else {
      stopMotionTimer()
    }
  }

  private func startMotionTimer() {
    stopMotionTimer()
    lastTickDate = nil

    let interval = MoveSpeedLimits.motionInterval(for: moveSpeed)
    let timer = DispatchSource.makeTimerSource(queue: .main)
    timer.schedule(deadline: .now(), repeating: interval, leeway: .milliseconds(48))
    timer.setEventHandler { [weak self] in
      self?.tick(at: Date())
    }
    timer.resume()
    motionTimer = timer
  }

  private func stopMotionTimer() {
    motionTimer?.cancel()
    motionTimer = nil
    lastTickDate = nil
  }

  private func tick(at date: Date) {
    let interval = MoveSpeedLimits.motionInterval(for: moveSpeed)
    let delta = min(
      lastTickDate.map { date.timeIntervalSince($0) } ?? interval,
      0.1
    )
    lastTickDate = date
    updatePosition(delta: delta)
  }

  private func updatePosition(delta: TimeInterval) {
    guard moveSpeed > 0 else { return }

    let effectiveWidth = screenSize.width
    let effectiveHeight = screenSize.height
    guard effectiveWidth > 0, effectiveHeight > 0 else { return }

    guard totalSize.width > 0 else {
      let center = screenCenter
      if position != center {
        position = center
        pushOffsetToRenderer()
      }
      return
    }

    let currentPos = position ?? screenCenter

    let minX = totalSize.width / 2
    let maxX = effectiveWidth - (totalSize.width / 2)
    let minY = totalSize.height / 2
    let maxY = effectiveHeight - (totalSize.height / 2)

    guard maxX >= minX, maxY >= minY else {
      if position != screenCenter {
        position = screenCenter
        pushOffsetToRenderer()
      }
      return
    }

    let step = CGFloat(MoveSpeedLimits.pixelsPerSecondFactor * moveSpeed) * CGFloat(delta)
    var newX = currentPos.x + direction.dx * step
    var newY = currentPos.y + direction.dy * step
    var didCollide = false

    if newX <= minX {
      newX = minX
      direction.dx = abs(direction.dx)
      didCollide = true
    } else if newX >= maxX {
      newX = maxX
      direction.dx = -abs(direction.dx)
      didCollide = true
    }

    if newY <= minY {
      newY = minY
      direction.dy = abs(direction.dy)
      didCollide = true
    } else if newY >= maxY {
      newY = maxY
      direction.dy = -abs(direction.dy)
      didCollide = true
    }

    let newPosition = CGPoint(x: newX, y: newY)
    if didCollide {
      clockColor = BackgroundColorPreset.randomCollisionColor(lightBackground: lightBackground)
      renderer?.setClockDisplayColor(clockColor)
    }

    if position != newPosition {
      position = newPosition
      pushOffsetToRenderer()
    }
  }

  private func pushOffsetToRenderer() {
    guard let position else {
      applyRendererOffset(.zero)
      return
    }
    let offset = CGSize(
      width: position.x - screenCenter.x,
      height: position.y - screenCenter.y
    )
    applyRendererOffset(offset)
  }

  private func applyRendererOffset(_ offset: CGSize) {
    let quantized = CGSize(
      width: offset.width.rounded(.toNearestOrAwayFromZero),
      height: offset.height.rounded(.toNearestOrAwayFromZero)
    )
    guard quantized != lastRenderedOffset else { return }
    lastRenderedOffset = quantized
    renderer?.setTranslation(quantized)
  }

  func clearTrail() {
    trailSamples = []
  }

  deinit {
    stopMotionTimer()
  }
}
