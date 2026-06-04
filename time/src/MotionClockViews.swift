import SwiftUI

/// 屏保级：原生 CATextLayer + layer transform 弹跳；无 NSHostingView
struct MotionClockScene: View {
  @State private var motion = ClockMotionEngine()
  let scheduler: ClockTimeScheduler
  let style: NativeClockStyle
  let precision: TimeDisplayPrecision
  let timeZoneTopGap: CGFloat
  let showTimeZoneText: Bool
  let moveSpeed: Double
  let isActive: Bool
  let isPaused: Bool
  let backgroundColorHex: String
  let fontColorHex: String

  var body: some View {
    MotionClockContent(
      scheduler: scheduler,
      motion: $motion,
      style: style,
      precision: precision,
      timeZoneTopGap: timeZoneTopGap,
      showTimeZoneText: showTimeZoneText,
      moveSpeed: moveSpeed,
      isActive: isActive,
      isPaused: isPaused,
      backgroundColorHex: backgroundColorHex,
      fontColorHex: fontColorHex
    )
  }
}

struct MotionClockContent: View {
  let scheduler: ClockTimeScheduler
  @Binding var motion: ClockMotionEngine
  let style: NativeClockStyle
  let precision: TimeDisplayPrecision
  let timeZoneTopGap: CGFloat
  let showTimeZoneText: Bool
  let moveSpeed: Double
  let isActive: Bool
  let isPaused: Bool
  let backgroundColorHex: String
  let fontColorHex: String

  private var styleStamp: ClockStyleStamp {
    ClockStyleStamp(
      style: style,
      precision: precision,
      timeZoneTopGap: timeZoneTopGap,
      color: motion.clockColor,
      showTimeZoneText: showTimeZoneText
    )
  }

  var body: some View {
    BouncingClockHost(
      scheduler: scheduler,
      motion: motion,
      styleStamp: styleStamp,
      moveSpeed: moveSpeed,
      isActive: isActive,
      isPaused: isPaused
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onAppear {
      motion.setMoveSpeed(moveSpeed)
      motion.setPaused(isPaused)
      motion.setMotionActive(isActive)
      motion.applyBackground(hex: backgroundColorHex)
      motion.applyUserClockColor(hex: fontColorHex)
      motion.clearTrail()
    }
    .onChange(of: scheduler.segments) { _, _ in
      motion.clearTrail()
    }
      .onChange(of: backgroundColorHex) { _, hex in
        motion.applyBackground(hex: hex)
        motion.applyUserClockColor(hex: fontColorHex)
      }
      .onChange(of: fontColorHex) { _, hex in
        motion.applyUserClockColor(hex: hex)
      }
      .onChange(of: moveSpeed) { _, newSpeed in
        motion.setMoveSpeed(newSpeed)
        if newSpeed > 0, !isPaused, isActive {
          motion.ensureBounceReady()
        }
      }
      .onChange(of: isActive) { _, active in
        motion.setMotionActive(active)
      }
      .onChange(of: isPaused) { _, paused in
        motion.setPaused(paused)
        if paused {
          motion.clearTrail()
        } else {
          motion.setMoveSpeed(moveSpeed)
          if isActive, moveSpeed > 0 {
            motion.ensureBounceReady()
          }
        }
      }
  }
}
