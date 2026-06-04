import SwiftUI

#if os(macOS)
  import AppKit
#else
  import UIKit
#endif

protocol NativeClockSizeDelegate: AnyObject {
  func nativeClock(didMeasure size: CGSize)
}

// MARK: - macOS

#if os(macOS)

  final class NativeClockNSView: NSView {
    weak var sizeDelegate: NativeClockSizeDelegate?

    private let rootLayer = CALayer()
    private let timeLayer = CATextLayer()
    private let timeZoneLayer = CATextLayer()

    private var stamp: ClockBounceStamp?
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
      rootLayer.addSublayer(timeLayer)
      rootLayer.addSublayer(timeZoneLayer)

      let scale = NSScreen.main?.backingScaleFactor ?? 2
      [timeLayer, timeZoneLayer].forEach {
        $0.contentsScale = scale
        $0.alignmentMode = .center
        $0.isWrapped = false
        $0.truncationMode = .none
      }
    }

    func apply(stamp: ClockBounceStamp) {
      self.stamp = stamp
      let color = stamp.color.platformColor
      timeLayer.string = NativeClockTextBuilder.timeAttributedString(
        segments: stamp.segments,
        style: stamp.style,
        precision: stamp.precision,
        color: color
      )
      if stamp.showTimeZoneText, !stamp.segments.timeZoneLabel.isEmpty {
        timeZoneLayer.isHidden = false
        timeZoneLayer.string = NativeClockTextBuilder.timeZoneAttributedString(
          stamp.segments.timeZoneLabel,
          style: stamp.style,
          color: color
        )
      } else {
        timeZoneLayer.isHidden = true
        timeZoneLayer.string = nil
      }
      needsLayout = true
    }

    override func layout() {
      super.layout()
      guard let stamp else { return }

      let color = stamp.color.platformColor
      measuredSize = NativeClockTextBuilder.measure(
        segments: stamp.segments,
        style: stamp.style,
        precision: stamp.precision,
        color: color,
        showTimeZone: stamp.showTimeZoneText,
        timeZoneTopGap: stamp.timeZoneTopGap
      )

      let timeBounds = (timeLayer.string as? NSAttributedString)?.boundingRect(
        with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin, .usesFontLeading]
      ).size ?? .zero

      let tzBounds: CGSize = {
        guard !timeZoneLayer.isHidden,
          let tz = timeZoneLayer.string as? NSAttributedString
        else { return .zero }
        return tz.boundingRect(
          with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
          options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).size
      }()

      let gap = stamp.showTimeZoneText ? max(0, stamp.timeZoneTopGap) : 0
      let totalW = max(timeBounds.width, tzBounds.width)
      let totalH = timeBounds.height + gap + tzBounds.height

      rootLayer.frame = CGRect(
        x: (bounds.width - totalW) / 2,
        y: (bounds.height - totalH) / 2,
        width: totalW,
        height: totalH
      )

      timeLayer.frame = CGRect(
        x: (totalW - timeBounds.width) / 2,
        y: tzBounds.height + gap,
        width: timeBounds.width,
        height: timeBounds.height
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

  final class NativeClockUIView: UIView {
    weak var sizeDelegate: NativeClockSizeDelegate?

    private let timeLayer = CATextLayer()
    private let timeZoneLayer = CATextLayer()

    private var stamp: ClockBounceStamp?
    private var measuredSize: CGSize = .zero

    override init(frame: CGRect) {
      super.init(frame: frame)
      isUserInteractionEnabled = false
      layer.addSublayer(timeLayer)
      layer.addSublayer(timeZoneLayer)
      let scale = UIScreen.main.scale
      [timeLayer, timeZoneLayer].forEach {
        $0.contentsScale = scale
        $0.alignmentMode = .center
        $0.isWrapped = false
        $0.truncationMode = .none
      }
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    func apply(stamp: ClockBounceStamp) {
      self.stamp = stamp
      let color = stamp.color.platformColor
      timeLayer.string = NativeClockTextBuilder.timeAttributedString(
        segments: stamp.segments,
        style: stamp.style,
        precision: stamp.precision,
        color: color
      )
      if stamp.showTimeZoneText, !stamp.segments.timeZoneLabel.isEmpty {
        timeZoneLayer.isHidden = false
        timeZoneLayer.string = NativeClockTextBuilder.timeZoneAttributedString(
          stamp.segments.timeZoneLabel,
          style: stamp.style,
          color: color
        )
      } else {
        timeZoneLayer.isHidden = true
        timeZoneLayer.string = nil
      }
      setNeedsLayout()
    }

    override func layoutSubviews() {
      super.layoutSubviews()
      guard let stamp else { return }

      let color = stamp.color.platformColor
      measuredSize = NativeClockTextBuilder.measure(
        segments: stamp.segments,
        style: stamp.style,
        precision: stamp.precision,
        color: color,
        showTimeZone: stamp.showTimeZoneText,
        timeZoneTopGap: stamp.timeZoneTopGap
      )

      let timeBounds = (timeLayer.string as? NSAttributedString)?.boundingRect(
        with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin, .usesFontLeading]
      ).size ?? .zero

      let tzBounds: CGSize = {
        guard !timeZoneLayer.isHidden,
          let tz = timeZoneLayer.string as? NSAttributedString
        else { return .zero }
        return tz.boundingRect(
          with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
          options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).size
      }()

      let gap = stamp.showTimeZoneText ? max(0, stamp.timeZoneTopGap) : 0
      let totalW = max(timeBounds.width, tzBounds.width)
      let totalH = timeBounds.height + gap + tzBounds.height
      let originX = (bounds.width - totalW) / 2
      let originY = (bounds.height - totalH) / 2

      timeLayer.frame = CGRect(
        x: originX + (totalW - timeBounds.width) / 2,
        y: originY + tzBounds.height + gap,
        width: timeBounds.width,
        height: timeBounds.height
      )

      timeZoneLayer.frame = CGRect(
        x: originX + (totalW - tzBounds.width) / 2,
        y: originY,
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
