import Foundation
import SwiftUI

struct MotionTrailSample: Identifiable, Equatable {
  let id: UUID
  let offset: CGSize
  let label: String
  let opacity: Double
}

extension TimeProvider {
  /// 弹跳残影用单行时间（不含时区）
  static func motionTrailLabel(from segments: TimeSegments, precision: TimeDisplayPrecision) -> String {
    let hour = segments.hourTens + segments.hourOnes
    let minute = segments.minuteTens + segments.minuteOnes
    var text = "\(hour):\(minute)"
    if precision.includesSeconds {
      text += ":\(segments.secondTens)\(segments.secondOnes)"
    }
    if !segments.leadingAMPM.isEmpty {
      return "\(segments.leadingAMPM) \(text)"
    }
    if !segments.trailingAMPM.isEmpty {
      return "\(text) \(segments.trailingAMPM)"
    }
    return text
  }
}

struct MotionClockTrailOverlay: View {
  let motion: ClockMotionEngine
  let fontSize: CGFloat
  let textColor: Color

  var body: some View {
    ZStack {
      ForEach(motion.trailSamples) { sample in
        Text(sample.label)
          .font(trailFont(scale: sample.opacity))
          .foregroundStyle(textColor.opacity(sample.opacity))
          .shadow(color: textColor.opacity(sample.opacity * 0.35), radius: 2)
          .offset(x: sample.offset.width, y: sample.offset.height)
      }
    }
    .allowsHitTesting(false)
  }

  private func trailFont(scale opacity: Double) -> Font {
    let size = fontSize * CGFloat(0.5 + opacity * 0.5)
    return .system(size: size, weight: .bold, design: .rounded).monospacedDigit()
  }
}
