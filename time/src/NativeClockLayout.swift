import CoreGraphics
import Foundation

#if os(macOS)
  import AppKit
#else
  import UIKit
#endif

/// 经典模式 AM/PM 角标（与翻页左下/右下一致，不挤进主时间字串）
enum NativeClockAMPMPlacement: Equatable {
  case none
  case leading(String)
  case trailing(String)

  static func from(segments: TimeSegments) -> NativeClockAMPMPlacement {
    if !segments.leadingAMPM.isEmpty { return .leading(segments.leadingAMPM) }
    if !segments.trailingAMPM.isEmpty { return .trailing(segments.trailingAMPM) }
    return .none
  }
}

enum NativeClockLayoutMetrics {
  static let ampmGapRatio: CGFloat = 0.05
  static let ampmEdgeInsetRatio: CGFloat = 0.08
}

enum AMPMVerticalAlign: String, Equatable {
  case top = "Top"
  case bottom = "Bottom"

  static func resolved(from raw: String) -> AMPMVerticalAlign {
    raw == Self.bottom.rawValue ? .bottom : .top
  }
}

struct NativeClockLayerFrames: Equatable {
  var totalSize: CGSize
  var timeZone: CGRect
  var time: CGRect
  var ampm: CGRect?
}

enum NativeClockLayoutEngine {
  static func frames(
    segments: TimeSegments,
    fonts: NativeClockFonts,
    precision: TimeDisplayPrecision,
    color: PlatformColor,
    showTimeZone: Bool,
    timeZoneTopGap: CGFloat,
    ampmVertical: String = AMPMVerticalAlign.top.rawValue
  ) -> NativeClockLayerFrames {
    let timeString = NativeClockTextBuilder.timeAttributedString(
      segments: segments,
      fonts: fonts,
      precision: precision,
      color: color,
      inlineAMPM: false
    )
    let timeSize = ceilSize(NativeClockTextMeasure.boundingSize(of: timeString))

    let ampmPlacement = NativeClockAMPMPlacement.from(segments: segments)
    let ampmString = ampmAttributedString(placement: ampmPlacement, fonts: fonts, color: color)
    let ampmSize = ampmString.map { ceilSize(NativeClockTextMeasure.boundingSize(of: $0)) } ?? .zero

    let gap = showTimeZone && !segments.timeZoneLabel.isEmpty
      ? max(0, timeZoneTopGap)
      : 0

    let tzSize: CGSize = {
      guard showTimeZone, !segments.timeZoneLabel.isEmpty else { return .zero }
      let tz = NSAttributedString(
        string: segments.timeZoneLabel,
        attributes: [.font: fonts.timeZone, .foregroundColor: color.withAlphaComponent(0.62)]
      )
      return ceilSize(NativeClockTextMeasure.boundingSize(of: tz))
    }()

    let ampmGap = ampmSize.width > 0 ? max(4, timeSize.height * NativeClockLayoutMetrics.ampmGapRatio) : 0
    let timeRowW: CGFloat
    switch ampmPlacement {
    case .none:
      timeRowW = timeSize.width
    case .leading:
      timeRowW = ampmSize.width + ampmGap + timeSize.width
    case .trailing:
      timeRowW = timeSize.width + ampmGap + ampmSize.width
    }

    let contentW = max(timeRowW, tzSize.width)
    let contentH = timeSize.height + gap + tzSize.height

    let rowX = (contentW - timeRowW) / 2
    let timeY = tzSize.height + gap

    let timeX: CGFloat
    let ampmFrame: CGRect?
    switch ampmPlacement {
    case .none:
      timeX = rowX + (timeRowW - timeSize.width) / 2
      ampmFrame = nil
    case .leading:
      timeX = rowX + ampmSize.width + ampmGap
      ampmFrame = CGRect(
        x: rowX,
        y: ampmY(
          vertical: AMPMVerticalAlign.resolved(from: ampmVertical),
          timeY: timeY,
          timeHeight: timeSize.height,
          ampmHeight: ampmSize.height
        ),
        width: ampmSize.width,
        height: ampmSize.height
      )
    case .trailing:
      timeX = rowX
      ampmFrame = CGRect(
        x: rowX + timeSize.width + ampmGap,
        y: ampmY(
          vertical: AMPMVerticalAlign.resolved(from: ampmVertical),
          timeY: timeY,
          timeHeight: timeSize.height,
          ampmHeight: ampmSize.height
        ),
        width: ampmSize.width,
        height: ampmSize.height
      )
    }

    return NativeClockLayerFrames(
      totalSize: CGSize(width: contentW, height: contentH),
      timeZone: CGRect(
        x: (contentW - tzSize.width) / 2,
        y: 0,
        width: tzSize.width,
        height: tzSize.height
      ),
      time: CGRect(
        x: timeX,
        y: timeY,
        width: timeSize.width,
        height: timeSize.height
      ),
      ampm: ampmFrame
    )
  }

  private static func ampmAttributedString(
    placement: NativeClockAMPMPlacement,
    fonts: NativeClockFonts,
    color: PlatformColor
  ) -> NSAttributedString? {
    let text: String
    switch placement {
    case .none: return nil
    case .leading(let value), .trailing(let value): text = value
    }
    return NSAttributedString(
      string: text,
      attributes: [.font: fonts.ampm, .foregroundColor: color]
    )
  }

  private static func ampmY(
    vertical: AMPMVerticalAlign,
    timeY: CGFloat,
    timeHeight: CGFloat,
    ampmHeight: CGFloat
  ) -> CGFloat {
    let edgePad = timeHeight * NativeClockLayoutMetrics.ampmEdgeInsetRatio
    switch vertical {
    case .top:
      return timeY + edgePad
    case .bottom:
      return timeY + timeHeight - ampmHeight - edgePad
    }
  }

  private static func ceilSize(_ size: CGSize) -> CGSize {
    CGSize(width: ceil(size.width), height: ceil(size.height))
  }
}
