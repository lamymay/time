import SwiftUI

#if os(macOS)
  import AppKit
#else
  import UIKit
#endif

protocol NativeClockSizeDelegate: AnyObject {
  func nativeClock(didMeasure size: CGSize)
}

private enum NativeClockLayoutHelper {
  static func bounds(of string: NSAttributedString?) -> CGSize {
    guard let string else { return .zero }
    return string.boundingRect(
      with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading]
    ).size
  }
}

// MARK: - macOS

#if os(macOS)

  final class NativeClockNSView: NSView, NativeClockTickTarget {
    weak var sizeDelegate: NativeClockSizeDelegate?

    private let rootLayer = CALayer()
    private let timeRowLayer = CALayer()
    private let mainTimeLayer = CATextLayer()
    private let millisTimeLayer = CATextLayer()
    private let timeZoneLayer = CATextLayer()

    private var styleStamp: ClockStyleStamp?
    private var fonts: NativeClockFonts?
    private var segments = TimeSegments()
    private var measuredSize: CGSize = .zero

    override init(frame frameRect: NSRect) {
      super.init(frame: frameRect)
      wantsLayer = true
      layer?.masksToBounds = false
      configureLayers()
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    private func configureLayers() {
      guard let layer else { return }
      layer.addSublayer(rootLayer)
      rootLayer.addSublayer(timeRowLayer)
      timeRowLayer.addSublayer(mainTimeLayer)
      timeRowLayer.addSublayer(millisTimeLayer)
      rootLayer.addSublayer(timeZoneLayer)

      let scale = NSScreen.main?.backingScaleFactor ?? 2
      [mainTimeLayer, millisTimeLayer, timeZoneLayer].forEach {
        $0.contentsScale = scale
        $0.alignmentMode = .center
        $0.isWrapped = false
        $0.truncationMode = .none
      }
      millisTimeLayer.isHidden = true
    }

    func applyStyle(_ stamp: ClockStyleStamp) {
      styleStamp = stamp
      fonts = NativeClockFonts.make(style: stamp.style)
      millisTimeLayer.isHidden = !stamp.precision.includesMilliseconds
      rebuildTimeLayers()
      needsLayout = true
    }

    func applyTick(segments: TimeSegments, changedFields: Set<TimeSegmentField>) {
      self.segments = segments
      guard let stamp = styleStamp, let fonts else { return }
      let color = stamp.color.platformColor

      if stamp.precision.includesMilliseconds,
        changedFields.allSatisfy({ $0 == .millis })
      {
        millisTimeLayer.string = NativeClockTextBuilder.millisAttributedString(
          segments: segments, fonts: fonts, color: color)
        return
      }

      rebuildTimeLayers()
      if stamp.showTimeZoneText, !segments.timeZoneLabel.isEmpty {
        timeZoneLayer.isHidden = false
        timeZoneLayer.string = NSAttributedString(
          string: segments.timeZoneLabel,
          attributes: [.font: fonts.timeZone, .foregroundColor: color]
        )
      } else {
        timeZoneLayer.isHidden = true
        timeZoneLayer.string = nil
      }
      needsLayout = true
    }

    private func rebuildTimeLayers() {
      guard let stamp = styleStamp, let fonts else { return }
      let color = stamp.color.platformColor
      mainTimeLayer.string = NativeClockTextBuilder.timeBodyAttributedString(
        segments: segments,
        fonts: fonts,
        precision: stamp.precision,
        color: color
      )
      if stamp.precision.includesMilliseconds {
        millisTimeLayer.string = NativeClockTextBuilder.millisAttributedString(
          segments: segments, fonts: fonts, color: color)
      } else {
        millisTimeLayer.string = nil
      }
    }

    override func layout() {
      super.layout()
      guard let stamp = styleStamp, let fonts else { return }

      let color = stamp.color.platformColor
      measuredSize = NativeClockTextBuilder.measure(
        segments: segments,
        fonts: fonts,
        precision: stamp.precision,
        color: color,
        showTimeZone: stamp.showTimeZoneText,
        timeZoneTopGap: stamp.timeZoneTopGap
      )

      let mainBounds = NativeClockLayoutHelper.bounds(of: mainTimeLayer.string as? NSAttributedString)
      let msBounds = NativeClockLayoutHelper.bounds(of: millisTimeLayer.string as? NSAttributedString)
      let rowW = mainBounds.width + msBounds.width
      let rowH = max(mainBounds.height, msBounds.height)

      let tzBounds: CGSize = {
        guard !timeZoneLayer.isHidden,
          let tz = timeZoneLayer.string as? NSAttributedString
        else { return .zero }
        return NativeClockLayoutHelper.bounds(of: tz)
      }()

      let gap = stamp.showTimeZoneText ? max(0, stamp.timeZoneTopGap) : 0
      let totalW = max(rowW, tzBounds.width)
      let totalH = rowH + gap + tzBounds.height

      rootLayer.frame = CGRect(
        x: (bounds.width - totalW) / 2,
        y: (bounds.height - totalH) / 2,
        width: totalW,
        height: totalH
      )

      timeRowLayer.frame = CGRect(
        x: (totalW - rowW) / 2,
        y: tzBounds.height + gap,
        width: rowW,
        height: rowH
      )

      mainTimeLayer.frame = CGRect(
        x: 0,
        y: (rowH - mainBounds.height) / 2,
        width: mainBounds.width,
        height: mainBounds.height
      )

      millisTimeLayer.frame = CGRect(
        x: mainBounds.width,
        y: (rowH - msBounds.height) / 2,
        width: msBounds.width,
        height: msBounds.height
      )

      timeZoneLayer.frame = CGRect(
        x: (totalW - tzBounds.width) / 2,
        y: 0,
        width: tzBounds.width,
        height: tzBounds.height
      )

      if measuredSize != .zero {
        sizeDelegate?.nativeClock(didMeasure: measuredSize)
      }
    }

    func fittingSize() -> CGSize {
      measuredSize == .zero ? CGSize(width: 1, height: 1) : measuredSize
    }
  }

#endif

// MARK: - iOS

#if os(iOS)

  final class NativeClockUIView: UIView, NativeClockTickTarget {
    weak var sizeDelegate: NativeClockSizeDelegate?

    private let rootLayer = CALayer()
    private let timeRowLayer = CALayer()
    private let mainTimeLayer = CATextLayer()
    private let millisTimeLayer = CATextLayer()
    private let timeZoneLayer = CATextLayer()

    private var styleStamp: ClockStyleStamp?
    private var fonts: NativeClockFonts?
    private var segments = TimeSegments()
    private var measuredSize: CGSize = .zero

    override init(frame: CGRect) {
      super.init(frame: frame)
      isUserInteractionEnabled = false
      layer.addSublayer(rootLayer)
      rootLayer.addSublayer(timeRowLayer)
      timeRowLayer.addSublayer(mainTimeLayer)
      timeRowLayer.addSublayer(millisTimeLayer)
      rootLayer.addSublayer(timeZoneLayer)
      let scale = UIScreen.main.scale
      [mainTimeLayer, millisTimeLayer, timeZoneLayer].forEach {
        $0.contentsScale = scale
        $0.alignmentMode = .center
        $0.isWrapped = false
        $0.truncationMode = .none
      }
      millisTimeLayer.isHidden = true
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    func applyStyle(_ stamp: ClockStyleStamp) {
      styleStamp = stamp
      fonts = NativeClockFonts.make(style: stamp.style)
      millisTimeLayer.isHidden = !stamp.precision.includesMilliseconds
      rebuildTimeLayers()
      setNeedsLayout()
    }

    func applyTick(segments: TimeSegments, changedFields: Set<TimeSegmentField>) {
      self.segments = segments
      guard let stamp = styleStamp, let fonts else { return }
      let color = stamp.color.platformColor

      if stamp.precision.includesMilliseconds,
        changedFields.allSatisfy({ $0 == .millis })
      {
        millisTimeLayer.string = NativeClockTextBuilder.millisAttributedString(
          segments: segments, fonts: fonts, color: color)
        return
      }

      rebuildTimeLayers()
      if stamp.showTimeZoneText, !segments.timeZoneLabel.isEmpty {
        timeZoneLayer.isHidden = false
        timeZoneLayer.string = NSAttributedString(
          string: segments.timeZoneLabel,
          attributes: [.font: fonts.timeZone, .foregroundColor: color]
        )
      } else {
        timeZoneLayer.isHidden = true
        timeZoneLayer.string = nil
      }
      setNeedsLayout()
    }

    private func rebuildTimeLayers() {
      guard let stamp = styleStamp, let fonts else { return }
      let color = stamp.color.platformColor
      mainTimeLayer.string = NativeClockTextBuilder.timeBodyAttributedString(
        segments: segments,
        fonts: fonts,
        precision: stamp.precision,
        color: color
      )
      if stamp.precision.includesMilliseconds {
        millisTimeLayer.string = NativeClockTextBuilder.millisAttributedString(
          segments: segments, fonts: fonts, color: color)
      } else {
        millisTimeLayer.string = nil
      }
    }

    override func layoutSubviews() {
      super.layoutSubviews()
      guard let stamp = styleStamp, let fonts else { return }

      let color = stamp.color.platformColor
      measuredSize = NativeClockTextBuilder.measure(
        segments: segments,
        fonts: fonts,
        precision: stamp.precision,
        color: color,
        showTimeZone: stamp.showTimeZoneText,
        timeZoneTopGap: stamp.timeZoneTopGap
      )

      let mainBounds = NativeClockLayoutHelper.bounds(of: mainTimeLayer.string as? NSAttributedString)
      let msBounds = NativeClockLayoutHelper.bounds(of: millisTimeLayer.string as? NSAttributedString)
      let rowW = mainBounds.width + msBounds.width
      let rowH = max(mainBounds.height, msBounds.height)

      let tzBounds: CGSize = {
        guard !timeZoneLayer.isHidden,
          let tz = timeZoneLayer.string as? NSAttributedString
        else { return .zero }
        return NativeClockLayoutHelper.bounds(of: tz)
      }()

      let gap = stamp.showTimeZoneText ? max(0, stamp.timeZoneTopGap) : 0
      let totalW = max(rowW, tzBounds.width)
      let totalH = rowH + gap + tzBounds.height
      let originX = (bounds.width - totalW) / 2
      let originY = (bounds.height - totalH) / 2

      rootLayer.frame = CGRect(x: originX, y: originY, width: totalW, height: totalH)

      timeRowLayer.frame = CGRect(
        x: (totalW - rowW) / 2,
        y: tzBounds.height + gap,
        width: rowW,
        height: rowH
      )

      mainTimeLayer.frame = CGRect(
        x: 0,
        y: (rowH - mainBounds.height) / 2,
        width: mainBounds.width,
        height: mainBounds.height
      )

      millisTimeLayer.frame = CGRect(
        x: mainBounds.width,
        y: (rowH - msBounds.height) / 2,
        width: msBounds.width,
        height: msBounds.height
      )

      timeZoneLayer.frame = CGRect(
        x: (totalW - tzBounds.width) / 2,
        y: 0,
        width: tzBounds.width,
        height: tzBounds.height
      )

      if measuredSize != .zero {
        sizeDelegate?.nativeClock(didMeasure: measuredSize)
      }
    }

    func fittingSize() -> CGSize {
      measuredSize == .zero ? CGSize(width: 1, height: 1) : measuredSize
    }
  }

#endif
