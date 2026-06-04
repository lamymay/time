import SwiftUI

// MARK: - Scheduler bridge

final class FlipClockTickBridge: NativeClockTickTarget {
  var onSegments: ((TimeSegments) -> Void)?

  func applyTick(segments: TimeSegments, changedFields: Set<TimeSegmentField>) {
    onSegments?(segments)
  }

  func applyStyle(_: ClockStyleStamp) {}
}

// MARK: - Scene

struct FlipClockScene: View {
  let scheduler: ClockTimeScheduler
  let config: ClockDisplayConfig
  let backgroundColorHex: String
  let isActive: Bool

  @State private var segments = TimeSegments()
  @State private var tickBridge = FlipClockTickBridge()

  private var preset: BackgroundColorPreset? {
    BackgroundColorPreset.from(hex: backgroundColorHex)
  }

  private var digitColor: Color {
    preset?.defaultClockColor ?? BackgroundColorPreset.black.defaultClockColor
  }

  private var cardColor: Color {
    preset?.isLight == true ? Color.black.opacity(0.07) : Color.white.opacity(0.1)
  }

  var body: some View {
    GeometryReader { geo in
      let layout = FlipClockLayout(segments: segments, config: config)
      let digitSize = FlipClockMetrics.digitSize(
        screen: geo.size,
        digitCount: layout.totalFlipDigits,
        configuredSize: config.fontSize
      )

      VStack(spacing: digitSize * 0.2) {
        FlipClockRow(
          layout: layout,
          digitSize: digitSize,
          digitColor: digitColor,
          cardColor: cardColor
        )

        if config.showTimeZoneText, !segments.timeZoneLabel.isEmpty {
          Text(segments.timeZoneLabel)
            .font(.system(size: digitSize * 0.14, weight: .medium, design: .rounded))
            .foregroundStyle(digitColor.opacity(0.75))
            .multilineTextAlignment(.center)
            .padding(.top, digitSize * 0.06)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .onAppear {
      tickBridge.onSegments = { segments = $0 }
      scheduler.setTickTarget(tickBridge)
      scheduler.setActive(isActive)
    }
    .onDisappear {
      scheduler.setTickTarget(nil)
    }
    .onChange(of: isActive) { _, active in
      scheduler.setActive(active)
    }
  }
}

// MARK: - Layout

private struct FlipClockLayout {
  let leadingAMPM: String
  let hourDigits: [String]
  let minuteDigits: [String]
  let secondDigits: [String]
  let trailingAMPM: String
  let showsSeconds: Bool

  var totalFlipDigits: Int {
    hourDigits.count + minuteDigits.count + secondDigits.count
  }

  init(segments: TimeSegments, config: ClockDisplayConfig) {
    leadingAMPM = segments.leadingAMPM
    if segments.hourTens.isEmpty {
      hourDigits = [segments.hourOnes]
    } else {
      hourDigits = [segments.hourTens, segments.hourOnes]
    }
    minuteDigits = [segments.minuteTens, segments.minuteOnes]
    showsSeconds = config.displayPrecision.includesSeconds
    secondDigits = showsSeconds ? [segments.secondTens, segments.secondOnes] : []
    trailingAMPM = segments.trailingAMPM
  }
}

private enum FlipClockMetrics {
  static func digitSize(screen: CGSize, digitCount: Int, configuredSize: Double) -> CGFloat {
    let count = max(digitCount, 4)
    let byWidth = screen.width / (CGFloat(count) * 0.95 + 1.8)
    let byHeight = screen.height * 0.22
    let auto = min(byWidth, byHeight)
    let preferred = CGFloat(configuredSize) * 0.55
    return min(max(auto, 56), max(preferred, 56))
  }
}

// MARK: - Row

private struct FlipClockRow: View {
  let layout: FlipClockLayout
  let digitSize: CGFloat
  let digitColor: Color
  let cardColor: Color

  var body: some View {
    HStack(alignment: .center, spacing: digitSize * 0.14) {
      if !layout.leadingAMPM.isEmpty {
        ampmLabel(layout.leadingAMPM)
      }

      digitGroup(layout.hourDigits)
      FlipColonView(size: digitSize, color: digitColor.opacity(0.85))
      digitGroup(layout.minuteDigits)

      if layout.showsSeconds {
        FlipColonView(size: digitSize, color: digitColor.opacity(0.85))
        digitGroup(layout.secondDigits)
      }

      if !layout.trailingAMPM.isEmpty {
        ampmLabel(layout.trailingAMPM)
      }
    }
  }

  private func digitGroup(_ digits: [String]) -> some View {
    HStack(spacing: digitSize * 0.1) {
      ForEach(Array(digits.enumerated()), id: \.offset) { _, char in
        FlipDigitView(
          character: char,
          fontSize: digitSize,
          textColor: digitColor,
          cardColor: cardColor
        )
      }
    }
  }

  private func ampmLabel(_ text: String) -> some View {
    Text(text)
      .font(.system(size: digitSize * 0.28, weight: .bold, design: .rounded))
      .foregroundStyle(digitColor.opacity(0.9))
      .padding(.horizontal, digitSize * 0.04)
  }
}

// MARK: - Colon

private struct FlipColonView: View {
  let size: CGFloat
  let color: Color

  var body: some View {
    let dot = size * 0.09
    VStack(spacing: size * 0.22) {
      Circle().fill(color).frame(width: dot, height: dot)
      Circle().fill(color).frame(width: dot, height: dot)
    }
    .frame(width: size * 0.2)
    .padding(.horizontal, size * 0.02)
  }
}

// MARK: - Flip digit (HTC-style flap)

private struct FlipDigitView: View {
  let character: String
  let fontSize: CGFloat
  let textColor: Color
  let cardColor: Color

  @State private var shown = "0"
  @State private var topFlapAngle: Double = 0
  @State private var bottomFlapAngle: Double = 90
  @State private var bottomFlapChar = "0"
  @State private var isFlipping = false

  private var target: String {
    let c = character.isEmpty ? "0" : character
    return String(c.prefix(1))
  }

  private var cardWidth: CGFloat { fontSize * 0.78 }
  private var cardHeight: CGFloat { fontSize * 1.42 }

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: fontSize * 0.09, style: .continuous)
        .fill(cardColor)
        .shadow(color: .black.opacity(0.28), radius: fontSize * 0.05, y: fontSize * 0.03)

      RoundedRectangle(cornerRadius: fontSize * 0.09, style: .continuous)
        .strokeBorder(Color.white.opacity(0.12), lineWidth: max(1, fontSize * 0.012))

      VStack(spacing: 0) {
        topHalf
        hinge
        bottomHalf
      }
      .clipShape(RoundedRectangle(cornerRadius: fontSize * 0.09, style: .continuous))
    }
    .frame(width: cardWidth, height: cardHeight)
    .onAppear {
      shown = target
      bottomFlapChar = target
      bottomFlapAngle = 0
    }
    .onChange(of: target) { _, new in
      guard new != shown else { return }
      runFlip(to: new)
    }
  }

  private var topHalf: some View {
    ZStack(alignment: .top) {
      digitLabel(shown)
        .frame(height: cardHeight / 2, alignment: .top)
        .clipped()

      if isFlipping {
        digitLabel(shown)
          .frame(height: cardHeight / 2, alignment: .top)
          .clipped()
          .rotation3DEffect(
            .degrees(topFlapAngle),
            axis: (x: 1, y: 0, z: 0),
            anchor: .bottom,
            perspective: 0.55
          )
      }
    }
    .frame(height: cardHeight / 2)
  }

  private var hinge: some View {
    Rectangle()
      .fill(Color.black.opacity(0.55))
      .frame(height: max(1.5, fontSize * 0.025))
  }

  private var bottomHalf: some View {
    ZStack(alignment: .bottom) {
      digitLabel(shown)
        .frame(height: cardHeight / 2, alignment: .bottom)
        .clipped()

      if isFlipping {
        digitLabel(bottomFlapChar)
          .frame(height: cardHeight / 2, alignment: .bottom)
          .clipped()
          .rotation3DEffect(
            .degrees(bottomFlapAngle),
            axis: (x: 1, y: 0, z: 0),
            anchor: .top,
            perspective: 0.55
          )
      }
    }
    .frame(height: cardHeight / 2)
  }

  private func digitLabel(_ char: String) -> some View {
    Text(char)
      .font(.system(size: fontSize, weight: .bold, design: .rounded))
      .monospacedDigit()
      .foregroundStyle(textColor)
      .frame(width: cardWidth, height: cardHeight)
      .background(cardColor)
  }

  private func runFlip(to new: String) {
    guard !isFlipping else {
      shown = new
      return
    }
    isFlipping = true
    bottomFlapChar = new
    bottomFlapAngle = 90
    topFlapAngle = 0

    withAnimation(.easeIn(duration: 0.16)) {
      topFlapAngle = -88
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
      shown = new
      withAnimation(.easeOut(duration: 0.18)) {
        bottomFlapAngle = 0
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        topFlapAngle = 0
        isFlipping = false
      }
    }
  }
}
