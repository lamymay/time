import SwiftUI

struct ClockBounceStamp: Equatable {
  var segments: TimeSegments
  var style: NativeClockStyle
  var precision: TimeDisplayPrecision
  var timeZoneTopGap: CGFloat
  var color: Color
  var showTimeZoneText: Bool
}

/// 屏保弹跳 + 纯原生 CATextLayer 时钟（无 NSHostingView）
struct BouncingClockHost: View {
  let motion: ClockMotionEngine
  let stamp: ClockBounceStamp

  var body: some View {
    #if os(macOS)
      MacBouncingClockHost(motion: motion, stamp: stamp)
    #else
      IOSBouncingClockHost(motion: motion, stamp: stamp)
    #endif
  }
}

#if os(macOS)

  private struct MacBouncingClockHost: NSViewRepresentable {
    let motion: ClockMotionEngine
    let stamp: ClockBounceStamp

    func makeCoordinator() -> Coordinator {
      Coordinator()
    }

    func makeNSView(context: Context) -> BounceContainerNSView {
      let container = BounceContainerNSView()
      let clock = NativeClockNSView()
      container.install(clock: clock)
      clock.apply(stamp: stamp)
      context.coordinator.motion = motion
      context.coordinator.container = container
      context.coordinator.clock = clock
      context.coordinator.stamp = stamp
      clock.sizeDelegate = context.coordinator
      motion.setRenderer(context.coordinator)
      return container
    }

    func updateNSView(_ container: BounceContainerNSView, context: Context) {
      guard let clock = context.coordinator.clock else { return }
      if context.coordinator.stamp != stamp {
        clock.apply(stamp: stamp)
        context.coordinator.stamp = stamp
        container.needsLayout = true
      }
    }

    static func dismantleNSView(_: BounceContainerNSView, coordinator: Coordinator) {
      coordinator.motion?.setRenderer(nil)
    }

    final class Coordinator: NSObject, ClockMotionRenderer, NativeClockSizeDelegate {
      weak var motion: ClockMotionEngine?
      weak var container: BounceContainerNSView?
      weak var clock: NativeClockNSView?
      var stamp: ClockBounceStamp?

      func setTranslation(_ offset: CGSize) {
        container?.setTranslation(offset)
      }

      func nativeClock(didMeasure size: CGSize) {
        guard let motion, motion.totalSize != size else { return }
        motion.totalSize = size
      }
    }
  }

  private final class BounceContainerNSView: NSView {
    private weak var clock: NativeClockNSView?

    func install(clock: NativeClockNSView) {
      self.clock = clock
      clock.translatesAutoresizingMaskIntoConstraints = true
      addSubview(clock)
    }

    func setTranslation(_ offset: CGSize) {
      guard let clock else { return }
      var transform = CATransform3DIdentity
      transform = CATransform3DTranslate(transform, offset.width, offset.height, 0)
      clock.layer?.transform = transform
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
    }
  }

#else

  private struct IOSBouncingClockHost: UIViewRepresentable {
    let motion: ClockMotionEngine
    let stamp: ClockBounceStamp

    func makeCoordinator() -> Coordinator {
      Coordinator()
    }

    func makeUIView(context: Context) -> BounceContainerUIView {
      let container = BounceContainerUIView()
      let clock = NativeClockUIView()
      container.install(clock: clock)
      clock.apply(stamp: stamp)
      context.coordinator.motion = motion
      context.coordinator.container = container
      context.coordinator.clock = clock
      context.coordinator.stamp = stamp
      clock.sizeDelegate = context.coordinator
      motion.setRenderer(context.coordinator)
      return container
    }

    func updateUIView(_ container: BounceContainerUIView, context: Context) {
      guard let clock = context.coordinator.clock else { return }
      if context.coordinator.stamp != stamp {
        clock.apply(stamp: stamp)
        context.coordinator.stamp = stamp
        container.setNeedsLayout()
      }
    }

    static func dismantleUIView(_: BounceContainerUIView, coordinator: Coordinator) {
      coordinator.motion?.setRenderer(nil)
    }

    final class Coordinator: NSObject, ClockMotionRenderer, NativeClockSizeDelegate {
      weak var motion: ClockMotionEngine?
      weak var container: BounceContainerUIView?
      weak var clock: NativeClockUIView?
      var stamp: ClockBounceStamp?

      func setTranslation(_ offset: CGSize) {
        container?.setTranslation(offset)
      }

      func nativeClock(didMeasure size: CGSize) {
        guard let motion, motion.totalSize != size else { return }
        motion.totalSize = size
      }
    }
  }

  private final class BounceContainerUIView: UIView {
    private weak var clock: NativeClockUIView?

    func install(clock: NativeClockUIView) {
      self.clock = clock
      clock.translatesAutoresizingMaskIntoConstraints = true
      addSubview(clock)
    }

    func setTranslation(_ offset: CGSize) {
      guard let clock else { return }
      clock.transform = CGAffineTransform(translationX: offset.width, y: offset.height)
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
    }
  }

#endif
