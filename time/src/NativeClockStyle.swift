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

enum NativeClockTextBuilder {
  static func timeAttributedString(
    segments: TimeSegments,
    style: NativeClockStyle,
    precision: TimeDisplayPrecision,
    color: PlatformColor
  ) -> NSAttributedString {
    let result = NSMutableAttributedString()
    let mainFont = PlatformFont.native(style.fontName, size: style.fontSize, weight: .bold)
    let ampmFont = PlatformFont.native(style.fontName, size: style.ampmSize, weight: .bold)
    let subFont = PlatformFont.native(style.fontName, size: style.subSecondSize, weight: .bold)
    let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: color]

    func append(_ text: String, font: PlatformFont) {
      guard !text.isEmpty else { return }
      var a = attrs
      a[.font] = font
      result.append(NSAttributedString(string: text, attributes: a))
    }

    append(segments.leadingAMPM, font: ampmFont)
    if !segments.leadingAMPM.isEmpty { append(" ", font: mainFont) }
    append(segments.hourTens, font: mainFont)
    append(segments.hourOnes, font: mainFont)
    append(":", font: mainFont)
    append(segments.minuteTens, font: mainFont)
    append(segments.minuteOnes, font: mainFont)
    if precision.includesSeconds {
      append(":", font: mainFont)
      append(segments.secondTens, font: subFont)
      append(segments.secondOnes, font: subFont)
    }
    if precision.includesMilliseconds {
      append(".", font: subFont)
      append(segments.millis, font: subFont)
    }
    if !segments.trailingAMPM.isEmpty {
      append(" ", font: mainFont)
      append(segments.trailingAMPM, font: ampmFont)
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
    style: NativeClockStyle,
    precision: TimeDisplayPrecision,
    color: PlatformColor,
    showTimeZone: Bool,
    timeZoneTopGap: CGFloat
  ) -> CGSize {
    let time = timeAttributedString(
      segments: segments, style: style, precision: precision, color: color)
    let timeSize = time.boundingRect(
      with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading]
    ).size

    guard showTimeZone, !segments.timeZoneLabel.isEmpty else {
      return CGSize(width: ceil(timeSize.width), height: ceil(timeSize.height))
    }

    let tz = timeZoneAttributedString(segments.timeZoneLabel, style: style, color: color)
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
