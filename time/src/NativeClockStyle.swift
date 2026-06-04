import SwiftUI

#if os(macOS)
  import AppKit
#else
  import UIKit
#endif

struct NativeClockStyle: Equatable {
  let fontSize: CGFloat
  let ampmScale: Double
  let fontName: String

  var ampmSize: CGFloat { fontSize * ampmScale }
  var subSecondSize: CGFloat { fontSize * 0.35 }
  var timeZoneSize: CGFloat { fontSize * 0.22 }

  static func resolve(fontSize: Double, ampmScale: Double, fontName: String) -> NativeClockStyle {
    NativeClockStyle(
      fontSize: CGFloat(fontSize),
      ampmScale: ampmScale,
      fontName: fontName
    )
  }
}

struct NativeClockFonts: Equatable {
  let main: PlatformFont
  let ampm: PlatformFont
  let sub: PlatformFont
  let timeZone: PlatformFont

  static func make(style: NativeClockStyle) -> NativeClockFonts {
    NativeClockFonts(
      main: PlatformFont.native(style.fontName, size: style.fontSize, weight: .bold),
      ampm: PlatformFont.native(style.fontName, size: style.ampmSize, weight: .bold),
      sub: PlatformFont.native(style.fontName, size: style.subSecondSize, weight: .bold),
      timeZone: PlatformFont.native(style.fontName, size: style.timeZoneSize, weight: .bold)
    )
  }
}

enum NativeClockTextBuilder {
  static func timeAttributedString(
    segments: TimeSegments,
    style: NativeClockStyle,
    precision: TimeDisplayPrecision,
    color: PlatformColor
  ) -> NSAttributedString {
    timeAttributedString(
      segments: segments,
      fonts: NativeClockFonts.make(style: style),
      precision: precision,
      color: color
    )
  }

  static func timeAttributedString(
    segments: TimeSegments,
    fonts: NativeClockFonts,
    precision: TimeDisplayPrecision,
    color: PlatformColor
  ) -> NSAttributedString {
    let result = NSMutableAttributedString()
    let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: color]

    func append(_ text: String, font: PlatformFont) {
      guard !text.isEmpty else { return }
      var a = attrs
      a[.font] = font
      result.append(NSAttributedString(string: text, attributes: a))
    }

    append(segments.leadingAMPM, font: fonts.ampm)
    if !segments.leadingAMPM.isEmpty { append(" ", font: fonts.main) }
    append(segments.hourTens, font: fonts.main)
    append(segments.hourOnes, font: fonts.main)
    append(":", font: fonts.main)
    append(segments.minuteTens, font: fonts.main)
    append(segments.minuteOnes, font: fonts.main)
    if precision.includesSeconds {
      append(":", font: fonts.main)
      append(segments.secondTens, font: fonts.sub)
      append(segments.secondOnes, font: fonts.sub)
    }
    if !segments.trailingAMPM.isEmpty {
      append(" ", font: fonts.main)
      append(segments.trailingAMPM, font: fonts.ampm)
    }
    return result
  }

  static func timeZoneAttributedString(
    _ text: String,
    style: NativeClockStyle,
    color: PlatformColor
  ) -> NSAttributedString {
    let font = PlatformFont.native(style.fontName, size: style.timeZoneSize, weight: .bold)
    return NSAttributedString(
      string: text,
      attributes: [.font: font, .foregroundColor: color]
    )
  }

  static func measure(
    segments: TimeSegments,
    fonts: NativeClockFonts,
    precision: TimeDisplayPrecision,
    color: PlatformColor,
    showTimeZone: Bool,
    timeZoneTopGap: CGFloat
  ) -> CGSize {
    let time = timeAttributedString(
      segments: segments, fonts: fonts, precision: precision, color: color)
    let timeSize = time.boundingRect(
      with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading]
    ).size

    guard showTimeZone, !segments.timeZoneLabel.isEmpty else {
      return CGSize(width: ceil(timeSize.width), height: ceil(timeSize.height))
    }

    let tz = NSAttributedString(
      string: segments.timeZoneLabel,
      attributes: [.font: fonts.timeZone, .foregroundColor: color]
    )
    let tzSize = tz.boundingRect(
      with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading]
    ).size

    let gap = max(0, timeZoneTopGap)
    return CGSize(
      width: ceil(max(timeSize.width, tzSize.width)),
      height: ceil(timeSize.height + gap + tzSize.height)
    )
  }

  static func measure(
    segments: TimeSegments,
    style: NativeClockStyle,
    precision: TimeDisplayPrecision,
    color: PlatformColor,
    showTimeZone: Bool,
    timeZoneTopGap: CGFloat
  ) -> CGSize {
    measure(
      segments: segments,
      fonts: NativeClockFonts.make(style: style),
      precision: precision,
      color: color,
      showTimeZone: showTimeZone,
      timeZoneTopGap: timeZoneTopGap
    )
  }
}

#if os(macOS)
  typealias PlatformColor = NSColor
  typealias PlatformFont = NSFont
#else
  typealias PlatformColor = UIColor
  typealias PlatformFont = UIFont
#endif

extension PlatformFont {
  static func native(_ name: String, size: CGFloat, weight: PlatformFont.Weight) -> PlatformFont {
    #if os(macOS)
      switch name {
      case "System Default":
        return NSFont.systemFont(ofSize: size, weight: mapWeight(weight))
      case "System Monospaced":
        return NSFont.monospacedDigitSystemFont(ofSize: size, weight: mapWeight(weight))
      case "System Rounded":
        if let descriptor = NSFont.systemFont(ofSize: size, weight: mapWeight(weight))
          .fontDescriptor.withDesign(.rounded)
        {
          return NSFont(descriptor: descriptor, size: size) ?? NSFont.systemFont(ofSize: size)
        }
        return NSFont.systemFont(ofSize: size, weight: mapWeight(weight))
      case "System Serif":
        if let descriptor = NSFont.systemFont(ofSize: size, weight: mapWeight(weight))
          .fontDescriptor.withDesign(.serif)
        {
          return NSFont(descriptor: descriptor, size: size) ?? NSFont.systemFont(ofSize: size)
        }
        return NSFont.systemFont(ofSize: size, weight: mapWeight(weight))
      default:
        return NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size, weight: mapWeight(weight))
      }
    #else
      switch name {
      case "System Default":
        return UIFont.systemFont(ofSize: size, weight: weight)
      case "System Monospaced":
        return UIFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
      case "System Rounded":
        if let descriptor = UIFont.systemFont(ofSize: size, weight: weight)
          .fontDescriptor.withDesign(.rounded)
        {
          return UIFont(descriptor: descriptor, size: size)
        }
        return UIFont.systemFont(ofSize: size, weight: weight)
      case "System Serif":
        if let descriptor = UIFont.systemFont(ofSize: size, weight: weight)
          .fontDescriptor.withDesign(.serif)
        {
          return UIFont(descriptor: descriptor, size: size)
        }
        return UIFont.systemFont(ofSize: size, weight: weight)
      default:
        return UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
      }
    #endif
  }

  #if os(macOS)
    private static func mapWeight(_ weight: PlatformFont.Weight) -> NSFont.Weight {
      switch weight {
      case .bold: return .bold
      case .semibold: return .semibold
      case .medium: return .medium
      default: return .regular
      }
    }
  #endif
}

extension Color {
  var platformColor: PlatformColor {
    #if os(macOS)
      NSColor(self)
    #else
      UIColor(self)
    #endif
  }
}
