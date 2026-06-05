import CoreGraphics
import Foundation

#if canImport(AppKit)
  import AppKit
#else
  import UIKit
#endif

/// 翻页时钟布局比例（双板 / 三等分逐位）
enum FlipClockLayoutMetrics {
  static let digitPanelHeightRatio: CGFloat = 1.42

  // 双板压缩（面板尽量贴数字，避免「框肥字小」）
  static let compactPanelHeightRatio: CGFloat = 1.22
  /// 板内数字高度占面板高度的比例
  static let compactPanelGlyphHeightFill: CGFloat = 0.84
  /// 多位数时字符间距（× digitSize），调小更紧、调大更疏
  static let compactIntraDigitGapRatio: CGFloat = 0.045
  static let compactPanelGapRatio: CGFloat = 0.07
  static let compactSecondGapRatio: CGFloat = 0.045
  static let compactSecondFontScale: CGFloat = 0.36
  static let compactSecondPanelHeightRatio: CGFloat = 2.52
  static let compactSecondPanelWidthCharScale: CGFloat = 0.68

  static func compactSecondPanelWidth(digitSize: CGFloat, charCount: Int) -> CGFloat {
    let base = digitSize * compactSecondPanelWidthCharScale
    return charCount <= 1 ? base : base * (1 + 0.42 * CGFloat(charCount - 1))
  }

  static func compactPanelWidthRatio(charCount: Int) -> CGFloat {
    let n = max(charCount, 1)
    let perChar: CGFloat = 0.56
    let sidePad: CGFloat = 0.14
    return sidePad + perChar * CGFloat(n)
  }

  static func compactPanelWidth(digitSize: CGFloat, charCount: Int) -> CGFloat {
    let n = max(charCount, 1)
    let gaps = CGFloat(max(0, n - 1)) * digitSize * compactIntraDigitGapRatio
    return digitSize * compactPanelWidthRatio(charCount: n) + gaps
  }

  static func compactIntraDigitGap(digitSize: CGFloat) -> CGFloat {
    digitSize * compactIntraDigitGapRatio
  }

  /// 翻页数字字号：与 digitSize 一致（滑块即可见数字高度）
  private static let glyphNaturalScale: CGFloat = 1.0
  /// 粗体数字平均字宽（相对字号），略保守以兼容 Silom 等宽体
  private static let glyphEmWidthPerCharacter: CGFloat = 0.58

  static func glyphFontSize(
    digitSize: CGFloat,
    panelWidth: CGFloat,
    charCount: Int
  ) -> CGFloat {
    let byDigit = digitSize * glyphNaturalScale
    let count = CGFloat(max(charCount, 1))
    let byWidth = panelWidth / (count * glyphEmWidthPerCharacter)
    return min(byDigit, byWidth)
  }

  /// 压缩双板：按面板高/宽与字间距共同决定字号
  static func compactGlyphFontSize(
    digitSize: CGFloat,
    panelWidth: CGFloat,
    panelHeight: CGFloat,
    charCount: Int
  ) -> CGFloat {
    let count = CGFloat(max(charCount, 1))
    let gapTotal = CGFloat(max(0, charCount - 1)) * compactIntraDigitGap(digitSize: digitSize)
    let byHeight = panelHeight * compactPanelGlyphHeightFill
    let byWidth = (panelWidth - gapTotal) / (count * glyphEmWidthPerCharacter)
    let byDigit = digitSize * 1.06
    return min(byHeight, byWidth, byDigit)
  }

  // 三等分逐位
  static let digitCardWidthRatio: CGFloat = 0.84
  static let digitGroupSpacingRatio: CGFloat = 0.08
  static let sectionSpacingRatio: CGFloat = 0.05
  static let colonWidthRatio: CGFloat = 0.10
  static let ampmWidthRatio: CGFloat = 0.44
}

/// 经典弹跳：上限由整行时间宽度决定；翻页：主限高度，并保证整行不超出屏宽。
enum ClockFontSizeLimits {
  static let classicMin: Double = 30
  static let flipMin: Double = 48

  private static let widthMargin: CGFloat = 0.985
  private static let measureColor = PlatformColor.white

  static func sliderRange(
    style: ClockDisplayStyle,
    screen: CGSize,
    config: ClockDisplayConfig
  ) -> ClosedRange<Double> {
    let maxV = maxSliderValue(style: style, screen: screen, config: config)
    switch style {
    case .classic:
      return classicMin...max(classicMin, maxV)
    case .flip:
      return flipMin...max(flipMin, maxV)
    }
  }

  static func maxSliderValue(
    style: ClockDisplayStyle,
    screen: CGSize,
    config: ClockDisplayConfig
  ) -> Double {
    switch style {
    case .classic:
      return classicMaxFontSize(screen: screen, config: config)
    case .flip:
      return Double(flipMaxDigitSize(screen: screen, config: config))
    }
  }

  /// 经典模式：不超过屏宽能容纳的最宽时间排版
  static func classicEffectiveFontSize(
    configured: Double,
    screen: CGSize,
    config: ClockDisplayConfig
  ) -> CGFloat {
    let maxF = classicMaxFontSize(screen: screen, config: config)
    let clamped = min(max(configured, classicMin), maxF)
    return CGFloat(clamped)
  }

  /// 翻页模式：滑块值为数字高度；受高度与整行宽度共同上限
  static func flipEffectiveDigitSize(
    configured: Double,
    screen: CGSize,
    config: ClockDisplayConfig
  ) -> CGFloat {
    let ceiling = flipMaxDigitSize(screen: screen, config: config)
    let preferred = CGFloat(configured)
    return min(max(preferred, CGFloat(flipMin)), ceiling)
  }

  static func flipMaxDigitSize(screen: CGSize, config: ClockDisplayConfig) -> CGFloat {
    let maxByHeight = flipMaxDigitSizeByHeight(screen: screen, config: config)
    let maxByWidth = flipMaxDigitSizeByWidth(screen: screen, config: config)
    return min(maxByHeight, maxByWidth)
  }

  static func flipMaxDigitSizeByHeight(screen: CGSize, config: ClockDisplayConfig) -> CGFloat {
    guard screen.height > 0 else { return 720 }
    let heightFraction: CGFloat = config.showTimeZoneText ? 0.78 : 0.94
    let ratio =
      config.flipFormat == .compactPanels
      ? FlipClockLayoutMetrics.compactPanelHeightRatio
      : 1.42
    return screen.height * heightFraction / ratio
  }

  static func flipRowWidth(digitSize: CGFloat, config: ClockDisplayConfig) -> CGFloat {
    switch config.flipFormat {
    case .compactPanels:
      return flipCompactRowWidth(digitSize: digitSize, config: config)
    case .tripleEqual:
      return flipTripleEqualRowWidth(digitSize: digitSize, config: config)
    }
  }

  private static func flipCompactRowWidth(digitSize: CGFloat, config: ClockDisplayConfig) -> CGFloat {
    let spec = flipCompactSpec(for: config)
    let d = digitSize
    let gap = d * FlipClockLayoutMetrics.compactPanelGapRatio
    let colon = d * FlipClockLayoutMetrics.colonWidthRatio
    let hourW = FlipClockLayoutMetrics.compactPanelWidth(digitSize: d, charCount: spec.hourCharCount)
    let minuteW = FlipClockLayoutMetrics.compactPanelWidth(digitSize: d, charCount: 2)
    var total = hourW + gap + colon + gap + minuteW

    // 压缩秒叠在分钟板内，不增加行宽
    if spec.trailingAMPM {
      total = max(total, hourW + gap + colon + gap + minuteW + d * 0.12)
    }

    return total
  }

  private static func flipTripleEqualRowWidth(digitSize: CGFloat, config: ClockDisplayConfig) -> CGFloat {
    let spec = flipTripleEqualSpec(for: config)
    let d = digitSize
    let cardW = d * FlipClockLayoutMetrics.digitCardWidthRatio
    let innerGap = d * FlipClockLayoutMetrics.digitGroupSpacingRatio
    let outerGap = d * FlipClockLayoutMetrics.sectionSpacingRatio
    let colonW = d * FlipClockLayoutMetrics.colonWidthRatio
    let ampmW = d * FlipClockLayoutMetrics.ampmWidthRatio

    func digitGroupWidth(count: Int) -> CGFloat {
      guard count > 0 else { return 0 }
      return CGFloat(count) * cardW + CGFloat(max(0, count - 1)) * innerGap
    }

    var segments: [CGFloat] = []
    if spec.leadingAMPM { segments.append(ampmW) }
    segments.append(digitGroupWidth(count: spec.hourDigits))
    segments.append(colonW)
    segments.append(digitGroupWidth(count: 2))
    if spec.showsSeconds {
      segments.append(colonW)
      segments.append(digitGroupWidth(count: 2))
    }
    if spec.trailingAMPM { segments.append(ampmW) }

    var width: CGFloat = 0
    for (index, part) in segments.enumerated() {
      width += part
      if index < segments.count - 1 {
        width += outerGap
      }
    }
    return width
  }

  private struct FlipCompactSpec {
    var hourCharCount: Int
    var showsDetachedSeconds: Bool
    var trailingAMPM: Bool
  }

  private struct FlipTripleEqualSpec {
    var hourDigits: Int
    var showsSeconds: Bool
    var leadingAMPM: Bool
    var trailingAMPM: Bool
  }

  private static func flipCompactSpec(for config: ClockDisplayConfig) -> FlipCompactSpec {
    let segments = widestSegments(for: config)
    let detached =
      config.flipFormat == .compactPanels
      && config.displayPrecision.includesSeconds
      && config.flipCompactDetachedSeconds
    return FlipCompactSpec(
      hourCharCount: segments.hourTens.isEmpty ? 1 : 2,
      showsDetachedSeconds: detached,
      trailingAMPM: !segments.trailingAMPM.isEmpty && !detached
    )
  }

  private static func flipTripleEqualSpec(for config: ClockDisplayConfig) -> FlipTripleEqualSpec {
    let segments = widestSegments(for: config)
    let fmt = config.formatOptions
    return FlipTripleEqualSpec(
      hourDigits: segments.hourTens.isEmpty ? 1 : 2,
      showsSeconds: fmt.displayPrecision.includesSeconds,
      leadingAMPM: false,
      trailingAMPM: false
    )
  }

  static func flipMaxDigitSizeByWidth(screen: CGSize, config: ClockDisplayConfig) -> CGFloat {
    guard screen.width > 0 else { return 720 }
    let maxWidth = screen.width * widthMargin
    var lo = flipMin
    var hi: Double = 2400

    while hi - lo > 0.5 {
      let mid = (lo + hi) / 2
      let w = flipRowWidth(digitSize: CGFloat(mid), config: config)
      if w <= maxWidth {
        lo = mid
      } else {
        hi = mid
      }
    }
    return CGFloat(floor(lo))
  }

  static func classicMaxFontSize(screen: CGSize, config: ClockDisplayConfig) -> Double {
    guard screen.width > 0 else { return 350 }

    let segments = widestSegments(for: config)
    let maxWidth = screen.width * widthMargin
    var lo = classicMin
    var hi: Double = 2400

    while hi - lo > 0.5 {
      let mid = (lo + hi) / 2
      let w = measuredTimeBlockWidth(fontSize: mid, segments: segments, config: config)
      if w <= maxWidth {
        lo = mid
      } else {
        hi = mid
      }
    }
    return floor(lo)
  }

  /// 快捷键 ⌘= / ⌘+ 放大、⌘- 缩小时的步进
  static let keyboardFontSizeStep: Double = 12

  static func clampStoredFontSize(
    _ fontSize: inout Double,
    style: ClockDisplayStyle,
    screen: CGSize,
    config: ClockDisplayConfig
  ) {
    let range = sliderRange(style: style, screen: screen, config: config)
    fontSize = min(max(fontSize, range.lowerBound), range.upperBound)
  }

  /// 翻页模式：将滑块字号设为当前屏幕下的上限
  static func applyFlipMaximumFontSize(
    _ fontSize: inout Double,
    screen: CGSize,
    config: ClockDisplayConfig
  ) {
    fontSize = maxSliderValue(style: .flip, screen: screen, config: config)
  }

  // MARK: - Measurement

  private static func measuredTimeBlockWidth(
    fontSize: Double,
    segments: TimeSegments,
    config: ClockDisplayConfig
  ) -> CGFloat {
    let style = NativeClockStyle.resolve(
      fontSize: fontSize,
      ampmScale: config.ampmScale,
      fontName: config.selectedFontName
    )
    let gap = CGFloat(-fontSize * 0.062)
    let size = NativeClockTextBuilder.measure(
      segments: segments,
      style: style,
      precision: config.displayPrecision,
      color: measureColor,
      showTimeZone: config.showTimeZoneText,
      timeZoneTopGap: gap,
      ampmVertical: config.ampmVertical
    )
    return size.width
  }

  /// 当前格式下最宽的时间排版（用于经典模式宽度上限）
  static func widestSegments(for config: ClockDisplayConfig) -> TimeSegments {
    var s = TimeSegments()
    let fmt = config.formatOptions

    if fmt.effectiveShowAMPM {
      if fmt.ampmSide == "Leading" {
        s.leadingAMPM = "PM"
      } else {
        s.trailingAMPM = "PM"
      }
    }

    if fmt.is24Hour {
      s.hourTens = "2"
      s.hourOnes = "3"
    } else if fmt.padZero {
      s.hourTens = "1"
      s.hourOnes = "2"
    } else {
      s.hourTens = "1"
      s.hourOnes = "2"
    }

    s.minuteTens = "5"
    s.minuteOnes = "9"
    if fmt.displayPrecision.includesSeconds {
      s.secondTens = "5"
      s.secondOnes = "9"
    }

    if fmt.showTimeZoneText {
      s.timeZoneLabel = widestTimeZoneLabel(for: fmt.timeZoneIdentifier)
    }
    return s
  }

  private static func widestTimeZoneLabel(for identifier: String) -> String {
    let now = Date()
    let selected = timeZoneLabel(for: identifier, date: now)
    let candidates = [
      selected,
      timeZoneLabel(for: "Pacific/Kiritimati", date: now),
      timeZoneLabel(for: "America/Argentina/Buenos_Aires", date: now),
    ]
    return candidates.max(by: { $0.count < $1.count }) ?? selected
  }

  private static func timeZoneLabel(for identifier: String, date: Date) -> String {
    let tz = TimeZone(identifier: identifier) ?? .current
    let city =
      identifier.split(separator: "/").last?.replacingOccurrences(of: "_", with: " ") ?? identifier
    let seconds = tz.secondsFromGMT(for: date)
    let hours = seconds / 3600
    let sign = hours >= 0 ? "+" : ""
    return "\(city) (GMT\(sign)\(hours))"
  }
}
