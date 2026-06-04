import SwiftUI

/// 屏保弹跳 + 纯原生 CATextLayer 时钟（无 NSHostingView）；时间 tick 由 ClockTimeScheduler 直推
struct BouncingClockHost: View {
  let scheduler: ClockTimeScheduler
  let motion: ClockMotionEngine
  let styleStamp: ClockStyleStamp
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
      container.onBoundsSizeChange = { [motion] size in
        motion.setScreenSize(size)
      }
      let clock = NativeClockNSView()
      container.install(clock: clock)
      clock.applyStyle(styleStamp)
      context.coordinator.scheduler = scheduler
      context.coordinator.motion = motion
      context.coordinator.container = container
      context.coordinator.clock = clock
      context.coordinator.styleStamp = styleStamp
      clock.sizeDelegate = context.coordinator
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
      syncMotionRuntime(container: container, context: context)
    }

    private func syncMotionRuntime(container: BounceContainerNSView, context: Context) {
      applyBoundsSize(container.bounds.size, to: context.coordinator.motion)
      context.coordinator.motion?.setMoveSpeed(moveSpeed)
      context.coordinator.motion?.setMotionActive(isActive)
      context.coordinator.motion?.setPaused(isPaused)
      if !isPaused, isActive, moveSpeed > 0 {
        context.coordinator.motion?.ensureBounceReady()
      }
    }

    private func applyBoundsSize(_ size: CGSize, to motion: ClockMotionEngine?) {
      guard size.width > 1, size.height > 1 else { return }
      motion?.setScreenSize(size)
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

      func setTranslation(_ offset: CGSize) {
        container?.setTranslation(offset)
      }

      func nativeClock(didMeasure size: CGSize) {
        guard let motion, motion.totalSize != size else { return }
        motion.totalSize = size
        motion.ensureBounceReady()
      }
    }
  }

  private final class BounceContainerNSView: NSView {
    private weak var clock: NativeClockNSView?
    private var translation: CGSize = .zero
    var onBoundsSizeChange: ((CGSize) -> Void)?
    private var lastReportedBounds: CGSize = .zero

    override var intrinsicContentSize: NSSize {
      NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    func install(clock: NativeClockNSView) {
      self.clock = clock
      clock.translatesAutoresizingMaskIntoConstraints = true
      addSubview(clock)
    }

    func setTranslation(_ offset: CGSize) {
      translation = offset
      applyTranslation()
    }

    override func layout() {
      super.layout()
      guard let clock else { return }
      let size = clock.fittingSize()
      clock.frame = CGRect(
        x: (bounds.width - size.width) / 2,
        y: (bounds.height - size.height) / 2,
        width: max(size.width, 1),
        height: max(size.height, 1)
      )
      applyTranslation()
      reportBoundsIfNeeded()
    }

    private func applyTranslation() {
      guard let clock else { return }
      var transform = CATransform3DIdentity
      transform = CATransform3DTranslate(transform, translation.width, translation.height, 0)
      clock.layer?.transform = transform
    }

    private func reportBoundsIfNeeded() {
      let size = bounds.size
      guard size.width > 1, size.height > 1, size != lastReportedBounds else { return }
      lastReportedBounds = size
      onBoundsSizeChange?(size)
    }
  }

#else

  private struct IOSBouncingClockHost: UIViewRepresentable {
    let scheduler: ClockTimeScheduler
    let motion: ClockMotionEngine
    let styleStamp: ClockStyleStamp
    let moveSpeed: Double
    let isActive: Bool
    let isPaused: Bool

    func makeCoordinator() -> Coordinator {
      Coordinator()
    }

    func makeUIView(context: Context) -> BounceContainerUIView {
      let container = BounceContainerUIView()
      container.onBoundsSizeChange = { [motion] size in
        motion.setScreenSize(size)
      }
      let clock = NativeClockUIView()
      container.install(clock: clock)
      clock.applyStyle(styleStamp)
      context.coordinator.scheduler = scheduler
      context.coordinator.motion = motion
      context.coordinator.container = container
      context.coordinator.clock = clock
      context.coordinator.styleStamp = styleStamp
      clock.sizeDelegate = context.coordinator
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
      syncMotionRuntime(container: container, context: context)
    }

    private func syncMotionRuntime(container: BounceContainerUIView, context: Context) {
      applyBoundsSize(container.bounds.size, to: context.coordinator.motion)
      context.coordinator.motion?.setMoveSpeed(moveSpeed)
      context.coordinator.motion?.setMotionActive(isActive)
      context.coordinator.motion?.setPaused(isPaused)
      if !isPaused, isActive, moveSpeed > 0 {
        context.coordinator.motion?.ensureBounceReady()
      }
    }

    private func applyBoundsSize(_ size: CGSize, to motion: ClockMotionEngine?) {
      guard size.width > 1, size.height > 1 else { return }
      motion?.setScreenSize(size)
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

      func setTranslation(_ offset: CGSize) {
        container?.setTranslation(offset)
      }

      func nativeClock(didMeasure size: CGSize) {
        guard let motion, motion.totalSize != size else { return }
        motion.totalSize = size
        motion.ensureBounceReady()
      }
    }
  }

  private final class BounceContainerUIView: UIView {
    private weak var clock: NativeClockUIView?
    private var translation: CGSize = .zero
    var onBoundsSizeChange: ((CGSize) -> Void)?
    private var lastReportedBounds: CGSize = .zero

    override var intrinsicContentSize: CGSize {
      CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }

    func install(clock: NativeClockUIView) {
      self.clock = clock
      clock.translatesAutoresizingMaskIntoConstraints = true
      addSubview(clock)
      setContentHuggingPriority(.defaultLow, for: .horizontal)
      setContentHuggingPriority(.defaultLow, for: .vertical)
      setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
      setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    }

    func setTranslation(_ offset: CGSize) {
      translation = offset
      applyTranslation()
    }

    override func layoutSubviews() {
      super.layoutSubviews()
      guard let clock else { return }
      let size = clock.fittingSize()
      clock.frame = CGRect(
        x: (bounds.width - size.width) / 2,
        y: (bounds.height - size.height) / 2,
        width: max(size.width, 1),
        height: max(size.height, 1)
      )
      applyTranslation()
      reportBoundsIfNeeded()
    }

    private func applyTranslation() {
      guard let clock else { return }
      clock.transform = CGAffineTransform(translationX: translation.width, y: translation.height)
    }

    private func reportBoundsIfNeeded() {
      let size = bounds.size
      guard size.width > 1, size.height > 1, size != lastReportedBounds else { return }
      lastReportedBounds = size
      onBoundsSizeChange?(size)
    }
  }

#endif
