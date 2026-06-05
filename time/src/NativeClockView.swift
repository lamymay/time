import SwiftUI

#if os(macOS)
  import AppKit
#else
  import UIKit
#endif

/// 碰撞盒与从中心到四边「视觉边」的距离（避免框内垂直居中导致离屏边仍有大空隙）
struct NativeClockCollisionExtents: Equatable {
  let frameSize: CGSize
  let centerInsetTop: CGFloat
  let centerInsetBottom: CGFloat
  let centerInsetLeft: CGFloat
  let centerInsetRight: CGFloat

  var collisionFootprint: CGSize {
    CGSize(
      width: centerInsetLeft + centerInsetRight,
      height: centerInsetTop + centerInsetBottom
    )
  }

  static let zero = NativeClockCollisionExtents(
    frameSize: .zero,
    centerInsetTop: 0,
    centerInsetBottom: 0,
    centerInsetLeft: 0,
    centerInsetRight: 0
  )
}

protocol NativeClockSizeDelegate: AnyObject {
  func nativeClock(didMeasure collision: NativeClockCollisionExtents)
}

private enum NativeClockLayoutHelper {
  static func bounds(of string: NSAttributedString?) -> CGSize {
    guard let string else { return .zero }
    return NativeClockTextMeasure.boundingSize(of: string)
  }
}

/// CATextLayer 实际绘制常略宽于排版估算；按 layer 并集顶左对齐，右侧单独留 glyph 溢出
private enum NativeClockCollisionMeasure {
  static let minHorizontalBleed: CGFloat = 4
  static let minVerticalBleed: CGFloat = 2

  static func horizontalPadding(for layoutTotal: CGSize) -> CGFloat {
    max(minHorizontalBleed, layoutTotal.width * 0.02)
  }

  static func verticalPadding(for layoutTotal: CGSize) -> CGFloat {
    max(minVerticalBleed, layoutTotal.height * 0.008)
  }

  /// 秒数等 CATextLayer 右侧可能略超出 union
  static func trailingGlyphSlop(for layoutTotal: CGSize) -> CGFloat {
    max(6, layoutTotal.width * 0.035)
  }

  static func measure(
    layoutTotal: CGSize,
    unionInView: CGRect
  ) -> NativeClockCollisionExtents {
    let padX = horizontalPadding(for: layoutTotal)
    let padY = verticalPadding(for: layoutTotal)
    let slopRight = trailingGlyphSlop(for: layoutTotal)

    let frameW: CGFloat
    let frameH: CGFloat
    if unionInView.isNull {
      frameW = max(ceil(layoutTotal.width) + 2 * padX, 1)
      frameH = max(ceil(layoutTotal.height) + 2 * padY, 1)
    } else {
      frameW = max(ceil(unionInView.width) + 2 * padX, 1)
      frameH = max(ceil(unionInView.height) + 2 * padY, 1)
    }

    let cx = frameW / 2
    let cy = frameH / 2

    if unionInView.isNull {
      return NativeClockCollisionExtents(
        frameSize: CGSize(width: frameW, height: frameH),
        centerInsetTop: cy,
        centerInsetBottom: cy,
        centerInsetLeft: cx,
        centerInsetRight: cx
      )
    }

    return NativeClockCollisionExtents(
      frameSize: CGSize(width: frameW, height: frameH),
      centerInsetTop: max(cy - unionInView.minY, 1),
      centerInsetBottom: max(unionInView.maxY - cy, 1),
      centerInsetLeft: max(cx - unionInView.minX, 1),
      centerInsetRight: max(unionInView.maxX - cx + slopRight, 1)
    )
  }
}

#if canImport(UIKit)
  import UIKit
#else
  import AppKit
#endif

/// 调试：紫框标出字形并集与碰撞 UIView 边界
private final class NativeClockDebugBorderLayers {
  private let glyphLayer = CALayer()
  private let frameLayer = CALayer()

  init() {
    let border = DVDCollisionDebug.borderCGColor
    glyphLayer.backgroundColor = PlatformColor.clear.cgColor
    glyphLayer.borderWidth = DVDCollisionDebug.glyphBoundsBorderWidth
    glyphLayer.borderColor = border
    frameLayer.backgroundColor = PlatformColor.clear.cgColor
    frameLayer.borderWidth = DVDCollisionDebug.collisionFrameBorderWidth
    frameLayer.borderColor = border
  }

  func install(on parent: CALayer) {
    parent.insertSublayer(frameLayer, at: 0)
    parent.insertSublayer(glyphLayer, at: 0)
  }

  func sync(glyphUnion: CGRect, collisionFrame: CGRect) {
    guard DVDCollisionDebug.isEnabled else {
      glyphLayer.isHidden = true
      frameLayer.isHidden = true
      return
    }
    glyphLayer.isHidden = glyphUnion.isNull
    frameLayer.isHidden = false
    glyphLayer.frame = glyphUnion
    frameLayer.frame = collisionFrame
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
    private var measuredCollision = NativeClockCollisionExtents.zero
    private var lastReportedCollision = NativeClockCollisionExtents.zero
    private let debugBorders = NativeClockDebugBorderLayers()

    override init(frame frameRect: NSRect) {
      super.init(frame: frameRect)
      wantsLayer = true
      layer?.masksToBounds = false
      configureLayers()
      if let layer {
        debugBorders.install(on: layer)
      }
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
      timeZoneLayer.frame = layout.timeZone
      timeLayer.frame = layout.time
      if let ampm = layout.ampm {
        ampmLayer.isHidden = false
        ampmLayer.frame = ampm
      } else {
        ampmLayer.isHidden = true
      }

      let padX = NativeClockCollisionMeasure.horizontalPadding(for: layout.totalSize)
      let padY = NativeClockCollisionMeasure.verticalPadding(for: layout.totalSize)
      let unionInRoot = layerUnionInRoot()
      measuredCollision = NativeClockCollisionMeasure.measure(
        layoutTotal: layout.totalSize,
        unionInView: unionInRoot.offsetBy(dx: padX, dy: padY)
      )
      rootLayer.frame = CGRect(
        x: padX,
        y: padY,
        width: measuredCollision.frameSize.width,
        height: measuredCollision.frameSize.height
      )
      let glyphUnion = unionInRoot.offsetBy(dx: padX, dy: padY)
      debugBorders.sync(
        glyphUnion: glyphUnion,
        collisionFrame: CGRect(origin: .zero, size: measuredCollision.frameSize)
      )
      reportMeasuredCollisionIfNeeded()
    }

    func fittingSize() -> CGSize {
      let size = measuredCollision.frameSize
      return size == .zero ? CGSize(width: 1, height: 1) : size
    }

    private func layerUnionInRoot() -> CGRect {
      var union = CGRect.null
      if !timeZoneLayer.isHidden { union = union.union(timeZoneLayer.frame) }
      union = union.union(timeLayer.frame)
      if !ampmLayer.isHidden { union = union.union(ampmLayer.frame) }
      return union
    }

    private func reportMeasuredCollisionIfNeeded() {
      let size = measuredCollision.frameSize
      guard size.width > 0, size.height > 0 else { return }
      guard measuredCollision != lastReportedCollision else { return }
      lastReportedCollision = measuredCollision
      sizeDelegate?.nativeClock(didMeasure: measuredCollision)
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
    private var measuredCollision = NativeClockCollisionExtents.zero
    private var lastReportedCollision = NativeClockCollisionExtents.zero
    private let debugBorders = NativeClockDebugBorderLayers()

    override init(frame: CGRect) {
      super.init(frame: frame)
      isUserInteractionEnabled = false
      debugBorders.install(on: layer)
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
      let padX = NativeClockCollisionMeasure.horizontalPadding(for: layout.totalSize)
      let padY = NativeClockCollisionMeasure.verticalPadding(for: layout.totalSize)
      let originX = padX
      let originY = padY

      timeZoneLayer.frame = layout.timeZone.offsetBy(dx: originX, dy: originY)
      timeLayer.frame = layout.time.offsetBy(dx: originX, dy: originY)
      if let ampm = layout.ampm {
        ampmLayer.isHidden = false
        ampmLayer.frame = ampm.offsetBy(dx: originX, dy: originY)
      } else {
        ampmLayer.isHidden = true
      }

      let glyphUnion = layerUnionInView()
      measuredCollision = NativeClockCollisionMeasure.measure(
        layoutTotal: layout.totalSize,
        unionInView: glyphUnion
      )
      debugBorders.sync(
        glyphUnion: glyphUnion,
        collisionFrame: CGRect(origin: .zero, size: measuredCollision.frameSize)
      )
      reportMeasuredCollisionIfNeeded()
    }

    func fittingSize() -> CGSize {
      let size = measuredCollision.frameSize
      return size == .zero ? CGSize(width: 1, height: 1) : size
    }

    private func layerUnionInView() -> CGRect {
      var union = CGRect.null
      if !timeZoneLayer.isHidden { union = union.union(timeZoneLayer.frame) }
      union = union.union(timeLayer.frame)
      if !ampmLayer.isHidden { union = union.union(ampmLayer.frame) }
      return union
    }

    private func reportMeasuredCollisionIfNeeded() {
      let size = measuredCollision.frameSize
      guard size.width > 0, size.height > 0 else { return }
      guard measuredCollision != lastReportedCollision else { return }
      lastReportedCollision = measuredCollision
      sizeDelegate?.nativeClock(didMeasure: measuredCollision)
    }
  }

#endif
