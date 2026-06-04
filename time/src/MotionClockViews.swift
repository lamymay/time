import SwiftUI

/// 屏保级：原生 CATextLayer + layer transform 弹跳；无 NSHostingView
struct MotionClockScene: View {
  @State private var motion = ClockMotionEngine()
  let scheduler: ClockTimeScheduler
  let style: NativeClockStyle
  let precision: TimeDisplayPrecision
  let timeZoneTopGap: CGFloat
  let showTimeZoneText: Bool
  let screenSize: CGSize
  let moveSpeed: Double
  let isActive: Bool
  let isPaused: Bool
  let backgroundColorHex: String

  var body: some View {
    MotionClockContent(
      scheduler: scheduler,
      motion: $motion,
      style: style,
      precision: precision,
      timeZoneTopGap: timeZoneTopGap,
      showTimeZoneText: showTimeZoneText,
      screenSize: screenSize,
      moveSpeed: moveSpeed,
      isActive: isActive,
      isPaused: isPaused,
      backgroundColorHex: backgroundColorHex
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
  let screenSize: CGSize
  let moveSpeed: Double
  let isActive: Bool
  let isPaused: Bool
  let backgroundColorHex: String

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
    BouncingClockHost(scheduler: scheduler, motion: motion, styleStamp: styleStamp)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onAppear {
      motion.setScreenSize(screenSize)
      motion.setMoveSpeed(moveSpeed)
      motion.setPaused(isPaused)
      motion.setMotionActive(isActive)
      motion.applyBackground(hex: backgroundColorHex)
      motion.clearTrail()
    }
    .onChange(of: scheduler.segments) { _, _ in
      motion.clearTrail()
    }
      .onChange(of: backgroundColorHex) { _, hex in
        motion.applyBackground(hex: hex)
      }
      .onChange(of: screenSize) { _, newSize in
        motion.setScreenSize(newSize)
      }
      .onChange(of: moveSpeed) { _, newSpeed in
        motion.setMoveSpeed(newSpeed)
      }
      .onChange(of: isActive) { _, active in
        motion.setMotionActive(active)
      }
      .onChange(of: isPaused) { _, paused in
        motion.setPaused(paused)
        if paused { motion.clearTrail() }
      }
  }
}
