import SwiftUI

/// 屏保级：原生 CATextLayer + layer transform 弹跳；无 NSHostingView
struct MotionClockScene: View {
  @State private var motion = ClockMotionEngine()
  @ObservedObject var scheduler: ClockTimeScheduler
  let style: NativeClockStyle
  let precision: TimeDisplayPrecision
  let timeZoneTopGap: CGFloat
  let showTimeZoneText: Bool
  let playfieldSize: CGSize
  let moveSpeed: Double
  let isActive: Bool
  let isPaused: Bool
  let backgroundColorHex: String
  let fontColorHex: String

  var body: some View {
    MotionClockContent(
      scheduler: scheduler,
      motion: motion,
      style: style,
      precision: precision,
      timeZoneTopGap: timeZoneTopGap,
      showTimeZoneText: showTimeZoneText,
      playfieldSize: playfieldSize,
      moveSpeed: moveSpeed,
      isActive: isActive,
      isPaused: isPaused,
      backgroundColorHex: backgroundColorHex,
      fontColorHex: fontColorHex
    )
  }
}

struct MotionClockContent: View {
  @ObservedObject var scheduler: ClockTimeScheduler
  /// 勿用 @Binding：引擎每帧更新 position 会拖垮 SwiftUI（主线程 9000ms+ 卡顿）
  let motion: ClockMotionEngine
  let style: NativeClockStyle
  let precision: TimeDisplayPrecision
  let timeZoneTopGap: CGFloat
  let showTimeZoneText: Bool
  let playfieldSize: CGSize
  let moveSpeed: Double
  let isActive: Bool
  let isPaused: Bool
  let backgroundColorHex: String
  let fontColorHex: String

  private var layoutField: CGSize {
    ClockScreenBounds.bouncePlayfield(swiftUISize: playfieldSize)
  }

  private var styleStamp: ClockStyleStamp {
    ClockStyleStamp(
      style: style,
      precision: precision,
      timeZoneTopGap: timeZoneTopGap,
      color: Color(hex: ColorPickerCodec.normalizedHex(fontColorHex)),
      showTimeZoneText: showTimeZoneText
    )
  }

  var body: some View {
    BouncingClockHost(
      scheduler: scheduler,
      motion: motion,
      styleStamp: styleStamp,
      playfieldSize: layoutField,
      moveSpeed: moveSpeed,
      isActive: isActive,
      isPaused: isPaused
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .fullScreenClockBleedIfAvailable()
    .onAppear {
      motion.setMoveSpeed(moveSpeed)
      motion.setPaused(isPaused)
      motion.setMotionActive(isActive)
      motion.applyBackground(hex: backgroundColorHex)
      motion.applyUserClockColor(hex: fontColorHex)
      motion.clearTrail()
    }
    .onChangeCompat(of: scheduler.segments) { _, _ in
      motion.clearTrail()
    }
    .onChangeCompat(of: backgroundColorHex) { _, hex in
      motion.applyBackground(hex: hex)
      motion.applyUserClockColor(hex: fontColorHex)
    }
    .onChangeCompat(of: fontColorHex) { _, hex in
      motion.applyUserClockColor(hex: hex)
    }
    .onChangeCompat(of: moveSpeed) { _, newSpeed in
      motion.setMoveSpeed(newSpeed)
      if newSpeed > 0, !isPaused, isActive {
        motion.ensureBounceReady()
      }
    }
    .onChangeCompat(of: isActive) { _, active in
      motion.setMotionActive(active)
    }
    .onChangeCompat(of: isPaused) { _, paused in
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
