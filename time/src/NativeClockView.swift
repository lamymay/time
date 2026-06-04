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
    return NativeClockTextMeasure.boundingSize(of: string)
  }
}

// MARK: - macOS

#if os(macOS)

  final class NativeClockNSView: NSView, NativeClockTickTarget {
    weak var sizeDelegate: NativeClockSizeDelegate?

    private let rootLayer = CALayer()
    private let timeLayer = CATextLayer()
    private let timeZoneLayer = CATextLayer()
    private let ampmLayer = CATextLayer()

    private var styleStamp: ClockStyleStamp?
    private var fonts: NativeClockFonts?
    private var segments = TimeSegments()
    private var measuredSize: CGSize = .zero
    private var lastReportedSize: CGSize = .zero

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
      rootLayer.addSublayer(timeLayer)
      rootLayer.addSublayer(timeZoneLayer)
      rootLayer.addSublayer(ampmLayer)

      let scale = NSScreen.main?.backingScaleFactor ?? 2
      [timeLayer, timeZoneLayer, ampmLayer].forEach {
        $0.contentsScale = scale
        $0.alignmentMode = .center
        $0.isWrapped = false
        $0.truncationMode = .none
      }
    }

    func applyStyle(_ stamp: ClockStyleStamp) {
      styleStamp = stamp
      fonts = NativeClockFonts.make(style: stamp.style)
      refreshLayers(needsLayout: true)
    }

    func setDisplayColor(_ color: Color) {
      guard var stamp = styleStamp else { return }
      stamp.color = color
      styleStamp = stamp
      refreshLayers(needsLayout: false)
    }

    func applyTick(segments: TimeSegments, changedFields: Set<TimeSegmentField>) {
      self.segments = segments
      let layoutNeeded = !changedFields.isSubset(of: [.secondTens, .secondOnes])
      refreshLayers(needsLayout: layoutNeeded)
    }

    private func refreshLayers(needsLayout: Bool) {
      guard let stamp = styleStamp, let fonts else { return }
      let color = stamp.color.platformColor

      timeLayer.string = NativeClockTextBuilder.timeAttributedString(
        segments: segments,
        fonts: fonts,
        precision: stamp.precision,
        color: color,
        inlineAMPM: false
      )

      switch NativeClockAMPMPlacement.from(segments: segments) {
      case .none:
        ampmLayer.isHidden = true
        ampmLayer.string = nil
      case .leading(let text), .trailing(let text):
        ampmLayer.isHidden = false
        ampmLayer.string = NSAttributedString(
          string: text,
          attributes: [.font: fonts.ampm, .foregroundColor: color]
        )
      }

      if stamp.showTimeZoneText, !segments.timeZoneLabel.isEmpty {
        timeZoneLayer.isHidden = false
        timeZoneLayer.string = NSAttributedString(
          string: segments.timeZoneLabel,
          attributes: [.font: fonts.timeZone, .foregroundColor: color.withAlphaComponent(0.62)]
        )
      } else {
        timeZoneLayer.isHidden = true
        timeZoneLayer.string = nil
      }

      if needsLayout {
        self.needsLayout = true
      }
    }

    override func layout() {
      super.layout()
      guard let stamp = styleStamp, let fonts else { return }

      let color = stamp.color.platformColor
      let layout = NativeClockLayoutEngine.frames(
        segments: segments,
        fonts: fonts,
        precision: stamp.precision,
        color: color,
        showTimeZone: stamp.showTimeZoneText,
        timeZoneTopGap: stamp.timeZoneTopGap
      )
      measuredSize = layout.totalSize

      rootLayer.frame = CGRect(
        x: (bounds.width - layout.totalSize.width) / 2,
        y: (bounds.height - layout.totalSize.height) / 2,
        width: layout.totalSize.width,
        height: layout.totalSize.height
      )

      timeZoneLayer.frame = layout.timeZone
      timeLayer.frame = layout.time
      if let ampm = layout.ampm {
        ampmLayer.isHidden = false
        ampmLayer.frame = ampm
      } else {
        ampmLayer.isHidden = true
      }

      reportMeasuredSizeIfNeeded()
    }

    func fittingSize() -> CGSize {
      measuredSize == .zero ? CGSize(width: 1, height: 1) : measuredSize
    }

    private func reportMeasuredSizeIfNeeded() {
      guard measuredSize.width > 0, measuredSize.height > 0 else { return }
      guard measuredSize != lastReportedSize else { return }
      lastReportedSize = measuredSize
      sizeDelegate?.nativeClock(didMeasure: measuredSize)
    }
  }

#endif

// MARK: - iOS

#if os(iOS)

  final class NativeClockUIView: UIView, NativeClockTickTarget {
    weak var sizeDelegate: NativeClockSizeDelegate?

    private let timeLayer = CATextLayer()
    private let timeZoneLayer = CATextLayer()
    private let ampmLayer = CATextLayer()

    private var styleStamp: ClockStyleStamp?
    private var fonts: NativeClockFonts?
    private var segments = TimeSegments()
    private var measuredSize: CGSize = .zero
    private var lastReportedSize: CGSize = .zero

    override init(frame: CGRect) {
      super.init(frame: frame)
      isUserInteractionEnabled = false
      layer.addSublayer(timeLayer)
      layer.addSublayer(timeZoneLayer)
      layer.addSublayer(ampmLayer)
      let scale = UIScreen.main.scale
      [timeLayer, timeZoneLayer, ampmLayer].forEach {
        $0.contentsScale = scale
        $0.alignmentMode = .center
        $0.isWrapped = false
        $0.truncationMode = .none
      }
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    func applyStyle(_ stamp: ClockStyleStamp) {
      styleStamp = stamp
      fonts = NativeClockFonts.make(style: stamp.style)
      refreshLayers(needsLayout: true)
    }

    func setDisplayColor(_ color: Color) {
      guard var stamp = styleStamp else { return }
      stamp.color = color
      styleStamp = stamp
      refreshLayers(needsLayout: false)
    }

    func applyTick(segments: TimeSegments, changedFields: Set<TimeSegmentField>) {
      self.segments = segments
      let layoutNeeded = !changedFields.isSubset(of: [.secondTens, .secondOnes])
      refreshLayers(needsLayout: layoutNeeded)
    }

    private func refreshLayers(needsLayout: Bool) {
      guard let stamp = styleStamp, let fonts else { return }
      let color = stamp.color.platformColor

      timeLayer.string = NativeClockTextBuilder.timeAttributedString(
        segments: segments,
        fonts: fonts,
        precision: stamp.precision,
        color: color,
        inlineAMPM: false
      )

      switch NativeClockAMPMPlacement.from(segments: segments) {
      case .none:
        ampmLayer.isHidden = true
        ampmLayer.string = nil
      case .leading(let text), .trailing(let text):
        ampmLayer.isHidden = false
        ampmLayer.string = NSAttributedString(
          string: text,
          attributes: [.font: fonts.ampm, .foregroundColor: color]
        )
      }

      if stamp.showTimeZoneText, !segments.timeZoneLabel.isEmpty {
        timeZoneLayer.isHidden = false
        timeZoneLayer.string = NSAttributedString(
          string: segments.timeZoneLabel,
          attributes: [.font: fonts.timeZone, .foregroundColor: color.withAlphaComponent(0.62)]
        )
      } else {
        timeZoneLayer.isHidden = true
        timeZoneLayer.string = nil
      }

      if needsLayout {
        setNeedsLayout()
      }
    }

    override func layoutSubviews() {
      super.layoutSubviews()
      guard let stamp = styleStamp, let fonts else { return }

      let color = stamp.color.platformColor
      let layout = NativeClockLayoutEngine.frames(
        segments: segments,
        fonts: fonts,
        precision: stamp.precision,
        color: color,
        showTimeZone: stamp.showTimeZoneText,
        timeZoneTopGap: stamp.timeZoneTopGap
      )
      measuredSize = layout.totalSize

      let originX = (bounds.width - layout.totalSize.width) / 2
      let originY = (bounds.height - layout.totalSize.height) / 2

      timeZoneLayer.frame = layout.timeZone.offsetBy(dx: originX, dy: originY)
      timeLayer.frame = layout.time.offsetBy(dx: originX, dy: originY)
      if let ampm = layout.ampm {
        ampmLayer.isHidden = false
        ampmLayer.frame = ampm.offsetBy(dx: originX, dy: originY)
      } else {
        ampmLayer.isHidden = true
      }

      reportMeasuredSizeIfNeeded()
    }

    func fittingSize() -> CGSize {
      measuredSize == .zero ? CGSize(width: 1, height: 1) : measuredSize
    }

    private func reportMeasuredSizeIfNeeded() {
      guard measuredSize.width > 0, measuredSize.height > 0 else { return }
      guard measuredSize != lastReportedSize else { return }
      lastReportedSize = measuredSize
      sizeDelegate?.nativeClock(didMeasure: measuredSize)
    }
  }

#endif
