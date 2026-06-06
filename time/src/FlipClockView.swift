import SwiftUI

// MARK: - Scheduler bridge

final class FlipClockTickBridge: NativeClockTickTarget {
  var onTick: ((TimeSegments, Set<TimeSegmentField>) -> Void)?

  func applyTick(segments: TimeSegments, changedFields: Set<TimeSegmentField>) {
    let handler = onTick
    if Thread.isMainThread {
      handler?(segments, changedFields)
    } else {
      DispatchQueue.main.async { handler?(segments, changedFields) }
    }
  }

  func applyStyle(_: ClockStyleStamp) {}

  func setDisplayColor(_: Color) {}
}

/// 与 scheduler tick 同步；子视图只观察此结构，避免 changedFields 在 onChange 里过期。
private struct FlipTickStamp: Equatable {
  var epoch: Int
  var value: String
}

// MARK: - Scene

struct FlipClockScene: View {
  @ObservedObject var scheduler: ClockTimeScheduler
  let config: ClockDisplayConfig
  let backgroundColorHex: String
  let flipCardColorHex: String
  let fontColorHex: String
  let isActive: Bool

  @State private var segments = TimeSegments()
  @State private var tickEpoch = 0
  private let tickBridge = FlipClockTickBridge()

  private var lightBackground: Bool {
    BackgroundColorPreset.from(hex: backgroundColorHex)?.isLight ?? false
  }

  private var cardStyle: FlipCardStyle {
    FlipCardStyle.resolve(faceHex: flipCardColorHex, lightBackground: lightBackground)
  }

  private var digitColor: Color {
    let picked = Color(hex: ColorPickerCodec.normalizedHex(fontColorHex))
    return FlipReadableColor.digitColor(preferred: picked, cardFace: cardStyle.face)
  }

  var body: some View {
    GeometryReader { geo in
      let layout = FlipClockLayout(segments: segments, config: config)
      let digitSize = FlipClockMetrics.digitSize(
        screen: geo.size,
        configuredSize: config.fontSize,
        config: config
      )
      VStack(spacing: digitSize * 0.2) {
        FlipClockRow(
          layout: layout,
          digitSize: digitSize,
          digitColor: digitColor,
          cardStyle: cardStyle,
          fontName: config.selectedFontName,
          tickEpoch: tickEpoch
        )

        if config.showTimeZoneText, !segments.timeZoneLabel.isEmpty {
          Text(segments.timeZoneLabel)
            .font(
              FlipClockFont.swiftUI(
                size: digitSize * NativeClockStyle.timeZoneScale,
                fontName: config.selectedFontName,
                weight: .regular
              )
            )
            .foregroundStyle(digitColor.opacity(0.55))
            .multilineTextAlignment(.center)
            .padding(.top, digitSize * 0.06)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .onAppear {
      attachScheduler()
    }
    .onDisappear {
      scheduler.setTickTarget(nil)
    }
    .onChangeCompat(of: isActive) { _, active in
      scheduler.setActive(active)
      if active { attachScheduler() }
    }
    .onChangeCompat(of: config) { _, _ in
      scheduler.setFormat(config.schedulerFormatOptions(for: .flip))
      attachScheduler()
    }
  }

  /// 与 DVD 弹跳钟相同：ClockTimeScheduler 按 displayPrecision 在秒/分边界 tick，直推 target。
  private func attachScheduler() {
    tickBridge.onTick = { newSegments, _ in
      segments = newSegments
      tickEpoch += 1
    }
    scheduler.setFormat(config.schedulerFormatOptions(for: .flip))
    scheduler.setTickTarget(tickBridge)
    if isActive {
      scheduler.setActive(true)
    }
  }
}

/// 设置全屏预览：直接渲染 segments，不连接 scheduler tick target
struct FlipClockPreview: View {
  let segments: TimeSegments
  let config: ClockDisplayConfig
  let backgroundColorHex: String
  let flipCardColorHex: String
  let fontColorHex: String
  let previewSize: CGSize

  private var lightBackground: Bool {
    BackgroundColorPreset.from(hex: backgroundColorHex)?.isLight ?? false
  }

  private var cardStyle: FlipCardStyle {
    FlipCardStyle.resolve(faceHex: flipCardColorHex, lightBackground: lightBackground)
  }

  private var digitColor: Color {
    let picked = Color(hex: ColorPickerCodec.normalizedHex(fontColorHex))
    return FlipReadableColor.digitColor(preferred: picked, cardFace: cardStyle.face)
  }

  var body: some View {
    GeometryReader { _ in
      let layout = FlipClockLayout(segments: segments, config: config)
      let digitSize = FlipClockMetrics.digitSize(
        screen: previewSize,
        configuredSize: config.fontSize,
        config: config
      )
      VStack(spacing: digitSize * 0.12) {
        FlipClockRow(
          layout: layout,
          digitSize: digitSize,
          digitColor: digitColor,
          cardStyle: cardStyle,
          fontName: config.selectedFontName,
          tickEpoch: 0
        )
        .animation(nil, value: config.flipFormat)
        .animation(nil, value: config.flipCompactDetachedSeconds)
        .animation(nil, value: config.displayPrecision)
        if config.showTimeZoneText, !segments.timeZoneLabel.isEmpty {
          Text(segments.timeZoneLabel)
            .font(
              FlipClockFont.swiftUI(
                size: digitSize * NativeClockStyle.timeZoneScale,
                fontName: config.selectedFontName,
                weight: .regular
              )
            )
            .foregroundStyle(digitColor.opacity(0.55))
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}

// MARK: - Layout

private struct FlipDigitSlot: Identifiable {
  let id: String
  let character: String
  let field: TimeSegmentField
}

private struct FlipClockLayout {
  let format: FlipClockFormat
  let slots: [FlipDigitSlot]
  let leadingAMPM: String
  let trailingAMPM: String
  let showsSeconds: Bool
  let showsDetachedSecondPanel: Bool
  let hourText: String
  let minuteText: String
  let secondTens: String
  let secondOnes: String
  /// 压缩版右下角秒（两位，与 scheduler 同步）
  var compactSecondsText: String {
    let s = secondTens + secondOnes
    return s.isEmpty ? "" : s
  }

  var compactSecondsDisplayText: String {
    compactSecondsText.isEmpty ? "00" : compactSecondsText
  }
  let detachedSecondText: String?
  let hourAMPM: String?
  let hourAMPMAlignment: Alignment
  let clockFormat: ClockFormatOptions

  init(segments: TimeSegments, config: ClockDisplayConfig) {
    format = config.flipFormat
    clockFormat = config.schedulerFormatOptions(for: .flip)
    leadingAMPM = segments.leadingAMPM
    trailingAMPM = segments.trailingAMPM
    showsSeconds = config.showsLiveSeconds
    let compactDetached = config.showsFlipDetachedSeconds
    showsDetachedSecondPanel = compactDetached

    if segments.hourTens.isEmpty {
      hourText = segments.hourOnes
    } else {
      hourText = segments.hourTens + segments.hourOnes
    }
    minuteText = segments.minuteTens + segments.minuteOnes
    secondTens = segments.secondTens
    secondOnes = segments.secondOnes
    detachedSecondText =
      compactDetached ? segments.secondTens + segments.secondOnes : nil

    if !segments.leadingAMPM.isEmpty {
      hourAMPM = segments.leadingAMPM
      hourAMPMAlignment = Self.ampmAlignment(
        isLeading: true,
        vertical: AMPMVerticalAlign.resolved(from: config.ampmVertical)
      )
    } else if !segments.trailingAMPM.isEmpty {
      hourAMPM = segments.trailingAMPM
      hourAMPMAlignment = Self.ampmAlignment(
        isLeading: false,
        vertical: AMPMVerticalAlign.resolved(from: config.ampmVertical)
      )
    } else {
      hourAMPM = nil
      hourAMPMAlignment = .topLeading
    }
    var list: [FlipDigitSlot] = []
    func add(_ id: String, _ char: String, _ field: TimeSegmentField) {
      guard !char.isEmpty else { return }
      list.append(FlipDigitSlot(id: id, character: char, field: field))
    }
    if segments.hourTens.isEmpty {
      add("hourOnes", segments.hourOnes, .hourOnes)
    } else {
      add("hourTens", segments.hourTens, .hourTens)
      add("hourOnes", segments.hourOnes, .hourOnes)
    }
    add("minuteTens", segments.minuteTens, .minuteTens)
    add("minuteOnes", segments.minuteOnes, .minuteOnes)
    if showsSeconds {
      add("secondTens", segments.secondTens, .secondTens)
      add("secondOnes", segments.secondOnes, .secondOnes)
    }
    slots = list
  }

  private static func ampmAlignment(isLeading: Bool, vertical: AMPMVerticalAlign) -> Alignment {
    switch (isLeading, vertical) {
    case (true, .top): return .topLeading
    case (true, .bottom): return .bottomLeading
    case (false, .top): return .topTrailing
    case (false, .bottom): return .bottomTrailing
    }
  }
}

private enum FlipClockMetrics {
  static func digitSize(
    screen: CGSize,
    configuredSize: Double,
    config: ClockDisplayConfig
  ) -> CGFloat {
    ClockFontSizeLimits.flipEffectiveDigitSize(
      configured: configuredSize,
      screen: screen,
      config: config
    )
  }
}

// MARK: - Card chrome

private struct FlipCardStyle {
  let face: Color
  let faceBottom: Color
  let shell: Color
  let border: Color
  let hinge: Color

  static func resolve(faceHex: String, lightBackground: Bool) -> FlipCardStyle {
    let trimmed = faceHex.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty,
      let custom = customFace(from: trimmed)
    {
      return FlipCardStyle(
        face: custom,
        faceBottom: custom.adjustedPickerBrightness(-0.05),
        shell: custom.adjustedPickerBrightness(-0.1),
        border: lightBackground ? Color.black.opacity(0.1) : Color.white.opacity(0.12),
        hinge: lightBackground ? Color.black.opacity(0.18) : Color.black.opacity(0.5)
      )
    }
    return FlipCardStyle(lightBackground: lightBackground)
  }

  private static func customFace(from hex: String) -> Color? {
    let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    return Color(hex: ColorPickerCodec.normalizedHex(trimmed))
  }

  init(lightBackground: Bool) {
    if lightBackground {
      face = Color(hex: "#ECECEF")
      faceBottom = Color(hex: "#E4E4EA")
      shell = Color(hex: "#E2E2E8")
      border = Color.black.opacity(0.1)
      hinge = Color.black.opacity(0.18)
    } else {
      face = Color(hex: "#46464C")
      faceBottom = Color(hex: "#404046")
      shell = Color(hex: "#3A3A40")
      border = Color.white.opacity(0.12)
      hinge = Color.black.opacity(0.5)
    }
  }

  private init(
    face: Color,
    faceBottom: Color,
    shell: Color,
    border: Color,
    hinge: Color
  ) {
    self.face = face
    self.faceBottom = faceBottom
    self.shell = shell
    self.border = border
    self.hinge = hinge
  }
}

// MARK: - Row

private struct FlipClockRow: View {
  let layout: FlipClockLayout
  let digitSize: CGFloat
  let digitColor: Color
  let cardStyle: FlipCardStyle
  let fontName: String
  let tickEpoch: Int

  var body: some View {
    switch layout.format {
    case .compactPanels:
      FlipCompactPanelsRow(
        layout: layout,
        digitSize: digitSize,
        digitColor: digitColor,
        cardStyle: cardStyle,
        fontName: fontName,
        tickEpoch: tickEpoch
      )
    case .tripleEqual:
      FlipTripleEqualRow(
        layout: layout,
        digitSize: digitSize,
        digitColor: digitColor,
        cardStyle: cardStyle,
        fontName: fontName,
        tickEpoch: tickEpoch
      )
    }
  }
}

// MARK: - 双板（压缩秒）

private struct FlipCompactPanelsRow: View {
  let layout: FlipClockLayout
  let digitSize: CGFloat
  let digitColor: Color
  let cardStyle: FlipCardStyle
  let fontName: String
  let tickEpoch: Int

  var body: some View {
    HStack(alignment: .center, spacing: digitSize * FlipClockLayoutMetrics.compactPanelGapRatio) {
      ZStack(alignment: layout.hourAMPMAlignment) {
        FlipPanelView(
          slotID: "hour",
          text: layout.hourText,
          fontSize: digitSize,
          textColor: digitColor,
          cardStyle: cardStyle,
          fontName: fontName,
          showsHinge: true,
          stamp: FlipTickStamp(epoch: tickEpoch, value: layout.hourText)
        )
        .id("hour")

        if let ampm = layout.hourAMPM {
          FlipCornerBadge(text: ampm, fontSize: digitSize * 0.16, color: digitColor, fontName: fontName)
            .ampmPadding(digitSize: digitSize, alignment: layout.hourAMPMAlignment)
        }
      }

      FlipColonView(size: digitSize, color: digitColor.opacity(0.85))

      ZStack(alignment: .bottomTrailing) {
        FlipPanelView(
          slotID: "minute",
          text: layout.minuteText,
          fontSize: digitSize,
          textColor: digitColor,
          cardStyle: cardStyle,
          fontName: fontName,
          showsHinge: true,
          stamp: FlipTickStamp(epoch: tickEpoch, value: layout.minuteText)
        )
        .id("minute")

        if layout.showsDetachedSecondPanel {
          let secondsText = layout.compactSecondsDisplayText
          FlipPanelView(
            slotID: "compactSeconds",
            text: secondsText,
            fontSize: digitSize * 0.16,
            textColor: digitColor,
            cardStyle: cardStyle,
            fontName: fontName,
            showsHinge: false,
            panelKind: .compactSecond,
            stamp: FlipTickStamp(epoch: tickEpoch, value: secondsText)
          )
          .ampmPadding(digitSize: digitSize, alignment: .bottomTrailing)
        }
      }
    }
  }
}

private struct FlipCornerBadge: View {
  let text: String
  let fontSize: CGFloat
  let color: Color
  let fontName: String

  var body: some View {
    Text(text)
      .font(FlipClockFont.swiftUI(size: fontSize, fontName: fontName))
      .foregroundStyle(color)
  }
}

private extension View {
  func ampmPadding(digitSize: CGFloat, alignment: Alignment) -> some View {
    let pad = digitSize * 0.08
    let isLeading = alignment == .topLeading || alignment == .bottomLeading
    let isTrailing = alignment == .topTrailing || alignment == .bottomTrailing
    let isTop = alignment == .topLeading || alignment == .topTrailing
    let isBottom = alignment == .bottomLeading || alignment == .bottomTrailing
    return padding(.leading, isLeading ? pad : 0)
      .padding(.trailing, isTrailing ? pad : 0)
      .padding(.top, isTop ? pad : 0)
      .padding(.bottom, isBottom ? pad : 0)
  }

}

// MARK: - 三等分逐位

private struct FlipTripleEqualRow: View {
  let layout: FlipClockLayout
  let digitSize: CGFloat
  let digitColor: Color
  let cardStyle: FlipCardStyle
  let fontName: String
  let tickEpoch: Int

  var body: some View {
    HStack(alignment: .center, spacing: digitSize * FlipClockLayoutMetrics.sectionSpacingRatio) {
      hourGroupWithAMPM

      FlipColonView(size: digitSize, color: digitColor.opacity(0.85))

      digitGroup(minuteSlots)

      if layout.showsSeconds {
        FlipColonView(size: digitSize, color: digitColor.opacity(0.85))
        digitGroup(secondSlots)
      }
    }
  }

  private var hourGroupWithAMPM: some View {
    ZStack(alignment: layout.hourAMPMAlignment) {
      digitGroup(hourSlots)
      if let ampm = layout.hourAMPM {
        FlipCornerBadge(text: ampm, fontSize: digitSize * 0.2, color: digitColor, fontName: fontName)
          .ampmPadding(digitSize: digitSize, alignment: layout.hourAMPMAlignment)
      }
    }
  }

  private func digitGroup(_ slots: [FlipDigitSlot]) -> some View {
    HStack(spacing: digitSize * FlipClockLayoutMetrics.digitGroupSpacingRatio) {
      ForEach(slots) { slot in
        FlipDigitView(
          slotID: slot.id,
          stamp: FlipTickStamp(epoch: tickEpoch, value: slot.character),
          fontSize: digitSize,
          textColor: digitColor,
          cardStyle: cardStyle,
          fontName: fontName
        )
        .id(slot.id)
      }
    }
  }

  private var hourSlots: [FlipDigitSlot] {
    layout.slots.filter { $0.id.hasPrefix("hour") }
  }

  private var minuteSlots: [FlipDigitSlot] {
    layout.slots.filter { $0.id.hasPrefix("minute") }
  }

  private var secondSlots: [FlipDigitSlot] {
    layout.slots.filter { $0.id.hasPrefix("second") }
  }

}

private struct FlipColonView: View {
  let size: CGFloat
  let color: Color

  var body: some View {
    let dot = size * 0.085
    VStack(spacing: size * 0.2) {
      Circle().fill(color).frame(width: dot, height: dot)
      Circle().fill(color).frame(width: dot, height: dot)
    }
    .frame(width: size * FlipClockLayoutMetrics.colonWidthRatio)
  }
}

// MARK: - 翻页动画

private enum FlipAnimPhase {
  case idle
  case topClosing
  case bottomOpening
}

private enum FlipAnimTiming {
  static let top: TimeInterval = 0.2
  static let bottom: TimeInterval = 0.22
}

// MARK: - 单位翻页

private struct FlipDigitView: View {
  let slotID: String
  let stamp: FlipTickStamp
  let fontSize: CGFloat
  let textColor: Color
  let cardStyle: FlipCardStyle
  let fontName: String

  @State private var committed = "0"
  @State private var pending: String?
  @State private var phase: FlipAnimPhase = .idle
  @State private var fromDigit = "0"
  @State private var toDigit = "0"
  @State private var topFlapAngle: Double = 0
  @State private var bottomFlapAngle: Double = 90
  @State private var flipGeneration = 0

  private var target: String {
    let c = stamp.value.isEmpty ? "0" : stamp.value
    return String(c.prefix(1))
  }

  private var cardWidth: CGFloat { fontSize * FlipClockLayoutMetrics.digitCardWidthRatio }
  private var cardHeight: CGFloat { fontSize * FlipClockLayoutMetrics.digitPanelHeightRatio }
  private var halfHeight: CGFloat { cardHeight / 2 }
  private var cornerRadius: CGFloat { fontSize * 0.1 }
  private var glyphSize: CGFloat {
    FlipClockLayoutMetrics.glyphFontSize(
      digitSize: fontSize,
      panelWidth: cardWidth,
      charCount: 1
    )
  }

  private var topShown: String {
    switch phase {
    case .idle, .topClosing: fromDigit
    case .bottomOpening: toDigit
    }
  }

  private var bottomShown: String { fromDigit }

  private var topDuration: TimeInterval { FlipAnimTiming.top }
  private var bottomDuration: TimeInterval { FlipAnimTiming.bottom }

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(cardStyle.shell)
        .shadow(color: .black.opacity(0.38), radius: fontSize * 0.06, y: fontSize * 0.04)

      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .strokeBorder(cardStyle.border, lineWidth: max(1, fontSize * 0.012))

      Group {
        if phase == .idle {
          idleDigitStack
        } else {
          VStack(spacing: 0) {
            topSection
            bottomSection
          }
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
      .overlay { hingeLine }
    }
    .frame(width: cardWidth, height: cardHeight)
    .onAppear {
      applyDigit(target, animated: false)
    }
    .onChangeCompat(of: stamp) { _, _ in
      requestFlipIfNeeded(target)
    }
  }

  private var idleDigitStack: some View {
    ZStack {
      VStack(spacing: 0) {
        cardStyle.face
          .frame(height: halfHeight)
        cardStyle.faceBottom
          .frame(height: halfHeight)
      }
      digitText(fromDigit)
    }
  }

  private var topSection: some View {
    ZStack(alignment: .top) {
      halfPane(char: topShown, isTop: true, fill: cardStyle.face)
      if phase == .topClosing {
        halfPane(char: fromDigit, isTop: true, fill: cardStyle.face)
          .rotation3DEffect(
            .degrees(topFlapAngle),
            axis: (x: 1, y: 0, z: 0),
            anchor: .bottom,
            perspective: 0.55
          )
          .animation(.easeIn(duration: topDuration), value: topFlapAngle)
          .opacity(topFlapAngle > -80 ? 1 : 0)
          .zIndex(1)
      }
    }
    .frame(height: halfHeight)
  }

  private var bottomSection: some View {
    ZStack(alignment: .bottom) {
      halfPane(char: bottomShown, isTop: false, fill: cardStyle.faceBottom)
      if phase == .bottomOpening {
        halfPane(char: toDigit, isTop: false, fill: cardStyle.faceBottom)
          .rotation3DEffect(
            .degrees(bottomFlapAngle),
            axis: (x: 1, y: 0, z: 0),
            anchor: .top,
            perspective: 0.55
          )
          .animation(.easeOut(duration: bottomDuration), value: bottomFlapAngle)
          .zIndex(1)
      }
    }
    .frame(height: halfHeight)
  }

  private var hingeLine: some View {
    ZStack {
      Rectangle()
        .fill(cardStyle.hinge)
        .frame(height: max(1, fontSize * 0.01))
      Rectangle()
        .fill(Color.white.opacity(0.07))
        .frame(height: max(0.5, fontSize * 0.004))
    }
    .allowsHitTesting(false)
  }

  private func requestFlipIfNeeded(_ new: String) {
    guard new != committed else { return }
    if phase == .idle {
      startFlip(to: new)
    } else {
      pending = new
    }
  }

  private func digitText(_ char: String) -> some View {
    Text(char)
      .font(FlipClockFont.swiftUI(size: glyphSize, fontName: fontName))
      .monospacedDigit()
      .foregroundStyle(textColor)
      .lineLimit(1)
      .frame(width: cardWidth, height: cardHeight, alignment: .center)
  }

  private func halfPane(char: String, isTop: Bool, fill: Color) -> some View {
    ZStack(alignment: isTop ? .top : .bottom) {
      fill
      digitText(char)
    }
    .frame(width: cardWidth, height: halfHeight, alignment: isTop ? .top : .bottom)
    .clipped()
  }

  private func applyDigit(_ digit: String, animated: Bool) {
    pending = nil
    if animated {
      startFlip(to: digit)
    } else {
      committed = digit
      fromDigit = digit
      toDigit = digit
      phase = .idle
      topFlapAngle = 0
      bottomFlapAngle = 90
    }
  }

  private func startFlip(to new: String) {
    guard new != committed else { return }
    flipGeneration += 1
    let generation = flipGeneration

    fromDigit = committed
    toDigit = new
    topFlapAngle = 0
    bottomFlapAngle = 90
    phase = .topClosing

    Task { @MainActor in
      withAnimation(.easeIn(duration: topDuration)) {
        topFlapAngle = -90
      }

      try? await Task.sleep(nanoseconds: UInt64(topDuration * 1_000_000_000))
      guard generation == flipGeneration, phase == .topClosing, toDigit == new else { return }

      phase = .bottomOpening
      withAnimation(.easeOut(duration: bottomDuration)) {
        bottomFlapAngle = 0
      }

      try? await Task.sleep(nanoseconds: UInt64(bottomDuration * 1_000_000_000))
      guard generation == flipGeneration, phase == .bottomOpening, toDigit == new else { return }

      committed = new
      fromDigit = new
      phase = .idle
      topFlapAngle = 0
      bottomFlapAngle = 90

      if let next = pending, next != committed {
        pending = nil
        startFlip(to: next)
      } else {
        pending = nil
      }
    }
  }
}

// MARK: - Flip panel (整板翻页 + 角标)

private enum FlipPanelKind {
  case hourMinute
  case compactSecond
}

private struct FlipPanelView: View {
  let slotID: String
  let text: String
  let fontSize: CGFloat
  let textColor: Color
  let cardStyle: FlipCardStyle
  let fontName: String
  var showsHinge: Bool = true
  var panelKind: FlipPanelKind = .hourMinute
  var stamp: FlipTickStamp = FlipTickStamp(epoch: 0, value: "0")

  @State private var committed = "0"
  @State private var pending: String?
  @State private var phase: FlipAnimPhase = .idle
  @State private var fromText = "0"
  @State private var toText = "0"
  @State private var topFlapAngle: Double = 0
  @State private var bottomFlapAngle: Double = 90
  @State private var flipGeneration = 0

  private var target: String {
    text.isEmpty ? "0" : text
  }

  private var cardWidth: CGFloat {
    switch panelKind {
    case .hourMinute:
      return FlipClockLayoutMetrics.compactPanelWidth(digitSize: fontSize, charCount: target.count)
    case .compactSecond:
      return FlipClockLayoutMetrics.compactSecondPanelWidth(digitSize: fontSize, charCount: target.count)
    }
  }

  private var cardHeight: CGFloat {
    switch panelKind {
    case .hourMinute:
      return fontSize * FlipClockLayoutMetrics.compactPanelHeightRatio
    case .compactSecond:
      return fontSize * FlipClockLayoutMetrics.compactSecondPanelHeightRatio
    }
  }

  private var halfHeight: CGFloat { cardHeight / 2 }
  private var cornerRadius: CGFloat { fontSize * (showsHinge ? 0.1 : 0.08) }
  private var glyphCharCount: Int { max(target.count, 1) }

  private var intraDigitGap: CGFloat {
    FlipClockLayoutMetrics.compactIntraDigitGap(digitSize: fontSize)
  }

  private var glyphSize: CGFloat {
    switch panelKind {
    case .hourMinute:
      return FlipClockLayoutMetrics.compactGlyphFontSize(
        digitSize: fontSize,
        panelWidth: cardWidth,
        panelHeight: cardHeight,
        charCount: glyphCharCount
      )
    case .compactSecond:
      return FlipClockLayoutMetrics.glyphFontSize(
        digitSize: fontSize,
        panelWidth: cardWidth,
        charCount: glyphCharCount
      )
    }
  }

  private var topDuration: TimeInterval { FlipAnimTiming.top }
  private var bottomDuration: TimeInterval { FlipAnimTiming.bottom }

  private var topShown: String {
    switch phase {
    case .idle, .topClosing: fromText
    case .bottomOpening: toText
    }
  }

  private var bottomShown: String { fromText }

  var body: some View {
    panelChrome
      .frame(width: cardWidth, height: cardHeight)
    .onAppear {
      applyText(target, animated: false)
    }
    .onChangeCompat(of: stamp) { _, _ in
      requestFlipIfNeeded(target)
    }
  }

  private var panelChrome: some View {
    ZStack {
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(cardStyle.shell)
        .shadow(color: .black.opacity(0.38), radius: fontSize * 0.06, y: fontSize * 0.04)

      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .strokeBorder(cardStyle.border, lineWidth: max(1, fontSize * 0.012))

      Group {
        if phase == .idle {
          idleTextStack
        } else {
          VStack(spacing: 0) {
            topSection
            bottomSection
          }
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
      .overlay {
        if showsHinge {
          hingeLine
        }
      }
    }
  }

  private var idleTextStack: some View {
    ZStack {
      if showsHinge {
        VStack(spacing: 0) {
          cardStyle.face
            .frame(height: halfHeight)
          cardStyle.faceBottom
            .frame(height: halfHeight)
        }
      } else {
        cardStyle.face
      }
      mainText(fromText)
    }
  }

  private var topSection: some View {
    ZStack(alignment: .top) {
      halfPane(char: topShown, isTop: true, fill: cardStyle.face)

      if phase == .topClosing {
        halfPane(char: fromText, isTop: true, fill: cardStyle.face)
          .rotation3DEffect(
            .degrees(topFlapAngle),
            axis: (x: 1, y: 0, z: 0),
            anchor: .bottom,
            perspective: 0.55
          )
          .animation(.easeIn(duration: topDuration), value: topFlapAngle)
          .opacity(topFlapAngle > -80 ? 1 : 0)
          .zIndex(1)
      }
    }
    .frame(height: halfHeight)
  }

  private var bottomSection: some View {
    let lowerFill = showsHinge ? cardStyle.faceBottom : cardStyle.face
    return ZStack(alignment: .bottom) {
      halfPane(char: bottomShown, isTop: false, fill: lowerFill)

      if phase == .bottomOpening {
        halfPane(char: toText, isTop: false, fill: lowerFill)
          .rotation3DEffect(
            .degrees(bottomFlapAngle),
            axis: (x: 1, y: 0, z: 0),
            anchor: .top,
            perspective: 0.55
          )
          .animation(.easeOut(duration: bottomDuration), value: bottomFlapAngle)
          .zIndex(1)
      }
    }
    .frame(height: halfHeight)
  }

  private var hingeLine: some View {
    ZStack {
      Rectangle()
        .fill(cardStyle.hinge)
        .frame(height: max(1, fontSize * 0.01))
      Rectangle()
        .fill(Color.white.opacity(0.07))
        .frame(height: max(0.5, fontSize * 0.004))
    }
    .allowsHitTesting(false)
  }

  private func requestFlipIfNeeded(_ new: String) {
    guard new != committed else { return }
    if phase == .idle {
      startFlip(to: new)
    } else {
      pending = new
    }
  }

  private func mainText(_ value: String) -> some View {
    Group {
      if panelKind == .hourMinute, value.count > 1 {
        HStack(spacing: intraDigitGap) {
          ForEach(Array(value.enumerated()), id: \.offset) { _, ch in
            Text(String(ch))
              .font(FlipClockFont.swiftUI(size: glyphSize, fontName: fontName))
              .monospacedDigit()
              .foregroundStyle(textColor)
          }
        }
      } else {
        Text(value)
          .font(FlipClockFont.swiftUI(size: glyphSize, fontName: fontName))
          .monospacedDigit()
          .foregroundStyle(textColor)
      }
    }
    .lineLimit(1)
    .frame(width: cardWidth, height: cardHeight, alignment: .center)
  }

  private func halfPane(char: String, isTop: Bool, fill: Color) -> some View {
    ZStack(alignment: isTop ? .top : .bottom) {
      fill
      mainText(char)
    }
    .frame(width: cardWidth, height: halfHeight, alignment: isTop ? .top : .bottom)
    .clipped()
  }

  // MARK: Animation

  private func applyText(_ value: String, animated: Bool) {
    pending = nil
    if animated {
      startFlip(to: value)
    } else {
      committed = value
      fromText = value
      toText = value
      phase = .idle
      topFlapAngle = 0
      bottomFlapAngle = 90
    }
  }

  private func startFlip(to new: String) {
    guard new != committed else { return }
    flipGeneration += 1
    let generation = flipGeneration

    fromText = committed
    toText = new
    topFlapAngle = 0
    bottomFlapAngle = 90
    phase = .topClosing

    Task { @MainActor in
      withAnimation(.easeIn(duration: topDuration)) {
        topFlapAngle = -90
      }

      try? await Task.sleep(nanoseconds: UInt64(topDuration * 1_000_000_000))
      guard generation == flipGeneration, phase == .topClosing, toText == new else { return }

      phase = .bottomOpening
      withAnimation(.easeOut(duration: bottomDuration)) {
        bottomFlapAngle = 0
      }

      try? await Task.sleep(nanoseconds: UInt64(bottomDuration * 1_000_000_000))
      guard generation == flipGeneration, phase == .bottomOpening, toText == new else { return }

      committed = new
      fromText = new
      phase = .idle
      topFlapAngle = 0
      bottomFlapAngle = 90

      if let next = pending, next != committed {
        pending = nil
        startFlip(to: next)
      } else {
        pending = nil
      }
    }
  }
}
