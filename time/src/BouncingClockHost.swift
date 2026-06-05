import SwiftUI

/// 屏保弹跳 + 纯原生 CATextLayer 时钟（无 NSHostingView）；时间 tick 由 ClockTimeScheduler 直推
struct BouncingClockHost: View {
  let scheduler: ClockTimeScheduler
  let motion: ClockMotionEngine
  let styleStamp: ClockStyleStamp
  /// 用于撑开 SwiftUI 布局；物理边界以 UIKit 容器 bounds 为准
  let playfieldSize: CGSize
  let moveSpeed: Double
  let isActive: Bool
  let isPaused: Bool

  var body: some View {
    #if os(macOS)
      MacBouncingClockHost(
        scheduler: scheduler,
        motion: motion,
        styleStamp: styleStamp,
        moveSpeed: moveSpeed,
        isActive: isActive,
        isPaused: isPaused
      )
    #else
      IOSBouncingClockHost(
        scheduler: scheduler,
        motion: motion,
        styleStamp: styleStamp,
        playfieldSize: playfieldSize,
        moveSpeed: moveSpeed,
        isActive: isActive,
        isPaused: isPaused
      )
    #endif
  }
}

#if os(macOS)

  private struct MacBouncingClockHost: NSViewRepresentable {
    let scheduler: ClockTimeScheduler
    let motion: ClockMotionEngine
    let styleStamp: ClockStyleStamp
    let moveSpeed: Double
    let isActive: Bool
    let isPaused: Bool

    func makeCoordinator() -> Coordinator {
      Coordinator()
    }

    func makeNSView(context: Context) -> BounceContainerNSView {
      let container = BounceContainerNSView()
      let clock = NativeClockNSView()
      container.install(clock: clock)
      clock.applyStyle(styleStamp)
      context.coordinator.scheduler = scheduler
      context.coordinator.motion = motion
      context.coordinator.container = container
      context.coordinator.clock = clock
      context.coordinator.styleStamp = styleStamp
      clock.sizeDelegate = context.coordinator
      container.onPlayfieldSizeChange = { [weak motion] size in
        motion?.setScreenSize(size)
      }
      motion.setRenderer(context.coordinator)
      scheduler.setTickTarget(clock)
      return container
    }

    func updateNSView(_ container: BounceContainerNSView, context: Context) {
      guard let clock = context.coordinator.clock else { return }
      if context.coordinator.styleStamp != styleStamp {
        clock.applyStyle(styleStamp)
        context.coordinator.styleStamp = styleStamp
        container.needsLayout = true
      }
      syncMotionRuntime(context: context)
    }

    private func syncMotionRuntime(context: Context) {
      context.coordinator.motion?.setMoveSpeed(moveSpeed)
      context.coordinator.motion?.setMotionActive(isActive)
      context.coordinator.motion?.setPaused(isPaused)
    }

    static func dismantleNSView(_: BounceContainerNSView, coordinator: Coordinator) {
      coordinator.scheduler?.setTickTarget(nil)
      coordinator.motion?.setRenderer(nil)
    }

    final class Coordinator: NSObject, ClockMotionRenderer, NativeClockSizeDelegate {
      weak var scheduler: ClockTimeScheduler?
      weak var motion: ClockMotionEngine?
      weak var container: BounceContainerNSView?
      weak var clock: NativeClockNSView?
      var styleStamp: ClockStyleStamp?

      func setClockCenter(_ center: CGPoint) {
        container?.setClockCenter(center)
      }

      func setClockDisplayColor(_ color: Color) {
        clock?.setDisplayColor(color)
      }

      func nativeClock(didMeasure collision: NativeClockCollisionExtents) {
        guard let motion else { return }
        let size = collision.frameSize
        if motion.totalSize != size { motion.totalSize = size }
        motion.setCollisionExtents(collision)
        motion.ensureBounceReady()
      }

    }
  }

  private final class BounceContainerNSView: NSView {
    private weak var clock: NativeClockNSView?
    private var clockCenter: CGPoint?
    private var lastReportedBounds: CGSize = .zero
    var onPlayfieldSizeChange: ((CGSize) -> Void)?

    override var intrinsicContentSize: NSSize {
      NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    func install(clock: NativeClockNSView) {
      self.clock = clock
      clock.translatesAutoresizingMaskIntoConstraints = true
      addSubview(clock)
    }

    func setClockCenter(_ center: CGPoint) {
      guard clockCenter != center else { return }
      clockCenter = center
      needsLayout = true
    }

    override func layout() {
      super.layout()
      reportPlayfieldIfNeeded()
      guard let clock else { return }
      let size = clock.fittingSize()
      let center = clockCenter ?? CGPoint(x: bounds.midX, y: bounds.midY)
      clock.frame = CGRect(
        x: center.x - size.width / 2,
        y: center.y - size.height / 2,
        width: max(size.width, 1),
        height: max(size.height, 1)
      )
      clock.layer?.transform = CATransform3DIdentity
    }

    private func reportPlayfieldIfNeeded() {
      let size = bounds.size
      guard size.width > 1, size.height > 1, size != lastReportedBounds else { return }
      lastReportedBounds = size
      onPlayfieldSizeChange?(size)
    }
  }

#else

  private struct IOSBouncingClockHost: UIViewRepresentable {
    let scheduler: ClockTimeScheduler
    let motion: ClockMotionEngine
    let styleStamp: ClockStyleStamp
    let playfieldSize: CGSize
    let moveSpeed: Double
    let isActive: Bool
    let isPaused: Bool

    func makeCoordinator() -> Coordinator {
      Coordinator()
    }

    func makeUIView(context: Context) -> BounceContainerUIView {
      let container = BounceContainerUIView()
      container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      let clock = NativeClockUIView()
      container.install(clock: clock)
      clock.applyStyle(styleStamp)
      context.coordinator.scheduler = scheduler
      context.coordinator.motion = motion
      context.coordinator.container = container
      context.coordinator.clock = clock
      context.coordinator.styleStamp = styleStamp
      clock.sizeDelegate = context.coordinator
      container.onPlayfieldSizeChange = { [weak motion] size in
        motion?.setScreenSize(size)
      }
      motion.setRenderer(context.coordinator)
      scheduler.setTickTarget(clock)
      return container
    }

    func updateUIView(_ container: BounceContainerUIView, context: Context) {
      guard let clock = context.coordinator.clock else { return }
      if context.coordinator.styleStamp != styleStamp {
        clock.applyStyle(styleStamp)
        context.coordinator.styleStamp = styleStamp
        container.setNeedsLayout()
      }
      syncMotionRuntime(context: context)
    }

    private func syncMotionRuntime(context: Context) {
      context.coordinator.motion?.setMoveSpeed(moveSpeed)
      context.coordinator.motion?.setMotionActive(isActive)
      context.coordinator.motion?.setPaused(isPaused)
    }

    static func dismantleUIView(_: BounceContainerUIView, coordinator: Coordinator) {
      coordinator.scheduler?.setTickTarget(nil)
      coordinator.motion?.setRenderer(nil)
    }

    final class Coordinator: NSObject, ClockMotionRenderer, NativeClockSizeDelegate {
      weak var scheduler: ClockTimeScheduler?
      weak var motion: ClockMotionEngine?
      weak var container: BounceContainerUIView?
      weak var clock: NativeClockUIView?
      var styleStamp: ClockStyleStamp?

      func setClockCenter(_ center: CGPoint) {
        container?.setClockCenter(center)
      }

      func setClockDisplayColor(_ color: Color) {
        clock?.setDisplayColor(color)
      }

      func nativeClock(didMeasure collision: NativeClockCollisionExtents) {
        guard let motion else { return }
        let size = collision.frameSize
        if motion.totalSize != size { motion.totalSize = size }
        motion.setCollisionExtents(collision)
        motion.ensureBounceReady()
      }
    }
  }

  private final class BounceContainerUIView: UIView {
    private weak var clock: NativeClockUIView?
    private var clockCenter: CGPoint?
    private var lastReportedBounds: CGSize = .zero
    var onPlayfieldSizeChange: ((CGSize) -> Void)?

    override var intrinsicContentSize: CGSize {
      CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }

    func install(clock: NativeClockUIView) {
      self.clock = clock
      clock.translatesAutoresizingMaskIntoConstraints = true
      addSubview(clock)
    }

    func setClockCenter(_ center: CGPoint) {
      guard clockCenter != center else { return }
      clockCenter = center
      setNeedsLayout()
    }

    override func layoutSubviews() {
      super.layoutSubviews()
      reportPlayfieldIfNeeded()
      guard let clock else { return }
      let size = clock.fittingSize()
      let center = clockCenter ?? CGPoint(x: bounds.midX, y: bounds.midY)
      clock.frame = CGRect(
        x: center.x - size.width / 2,
        y: center.y - size.height / 2,
        width: max(size.width, 1),
        height: max(size.height, 1)
      )
      clock.transform = .identity
    }

    private func reportPlayfieldIfNeeded() {
      let size = bounds.size
      guard size.width > 1, size.height > 1, size != lastReportedBounds else { return }
      lastReportedBounds = size
      onPlayfieldSizeChange?(size)
    }
  }

#endif
