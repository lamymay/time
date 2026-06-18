import SwiftUI

#if os(macOS)
  import AppKit
#endif
#if os(iOS)
  import UIKit
#endif

extension View {
  /// 翻页模式：Mac 触控板双指缩放，调整 `fontSize`（iOS 见 `FlipClockIOSInteractionOverlay`）
  func flipClockPinchZoom(
    fontSize: Binding<Double>,
    enabled: Bool,
    screen: CGSize,
    config: ClockDisplayConfig
  ) -> some View {
    modifier(
      FlipClockPinchZoomModifier(
        fontSize: fontSize,
        enabled: enabled,
        screen: screen,
        config: config
      )
    )
  }
}

#if os(iOS)
  /// 全屏透明交互层：长按开设置 + 翻页模式双指缩放（须在时钟层之上）
  struct FlipClockIOSInteractionOverlay: UIViewRepresentable {
    let isEnabled: Bool
    let pinchZoomEnabled: Bool
    @Binding var fontSize: Double
    let screen: CGSize
    let config: ClockDisplayConfig
    let onLongPress: () -> Void

    func makeCoordinator() -> Coordinator {
      Coordinator(
        fontSize: $fontSize,
        screen: screen,
        config: config,
        onLongPress: onLongPress
      )
    }

    func makeUIView(context: Context) -> FlipClockIOSInteractionUIView {
      let view = FlipClockIOSInteractionUIView()
      view.coordinator = context.coordinator
      view.applyInteractionState(isEnabled: isEnabled, pinchZoomEnabled: pinchZoomEnabled)
      return view
    }

    func updateUIView(_ uiView: FlipClockIOSInteractionUIView, context: Context) {
      context.coordinator.fontSize = $fontSize
      context.coordinator.screen = screen
      context.coordinator.config = config
      context.coordinator.onLongPress = onLongPress
      uiView.coordinator = context.coordinator
      uiView.applyInteractionState(isEnabled: isEnabled, pinchZoomEnabled: pinchZoomEnabled)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
      var fontSize: Binding<Double>
      var screen: CGSize
      var config: ClockDisplayConfig
      var onLongPress: () -> Void
      var pinchBaseFontSize: Double?

      init(
        fontSize: Binding<Double>,
        screen: CGSize,
        config: ClockDisplayConfig,
        onLongPress: @escaping () -> Void
      ) {
        self.fontSize = fontSize
        self.screen = screen
        self.config = config
        self.onLongPress = onLongPress
      }

      func clamp(_ value: Double) -> Double {
        var v = value
        ClockFontSizeLimits.clampStoredFontSize(
          &v,
          style: .flip,
          screen: screen,
          config: config
        )
        return v
      }

      func gestureRecognizer(
        _: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer
      ) -> Bool {
        true
      }
    }
  }

  final class FlipClockIOSInteractionUIView: UIView {
    weak var coordinator: FlipClockIOSInteractionOverlay.Coordinator?

    private let longPress = UILongPressGestureRecognizer()
    private let pinch = UIPinchGestureRecognizer()

    override init(frame: CGRect) {
      super.init(frame: frame)
      backgroundColor = .clear
      isMultipleTouchEnabled = true

      longPress.minimumPressDuration = 0.35
      longPress.allowableMovement = 48
      longPress.addTarget(self, action: #selector(handleLongPress(_:)))
      addGestureRecognizer(longPress)

      pinch.addTarget(self, action: #selector(handlePinch(_:)))
      addGestureRecognizer(pinch)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    func applyInteractionState(isEnabled: Bool, pinchZoomEnabled: Bool) {
      isUserInteractionEnabled = isEnabled
      longPress.isEnabled = isEnabled
      pinch.isEnabled = isEnabled && pinchZoomEnabled
      longPress.delegate = coordinator
      pinch.delegate = coordinator
    }

    @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
      guard recognizer.state == .began else { return }
      coordinator?.onLongPress()
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
      guard let coordinator else { return }
      switch recognizer.state {
      case .began:
        coordinator.pinchBaseFontSize = coordinator.fontSize.wrappedValue
      case .changed, .ended:
        guard let base = coordinator.pinchBaseFontSize else { return }
        coordinator.fontSize.wrappedValue = coordinator.clamp(base * Double(recognizer.scale))
      case .cancelled, .failed:
        coordinator.pinchBaseFontSize = nil
      default:
        break
      }
      if recognizer.state == .ended || recognizer.state == .cancelled || recognizer.state == .failed {
        coordinator.pinchBaseFontSize = nil
      }
    }
  }
#endif

private struct FlipClockPinchZoomModifier: ViewModifier {
  @Binding var fontSize: Double
  let enabled: Bool
  let screen: CGSize
  let config: ClockDisplayConfig

  @State private var pinchStartFontSize: Double?
  @State private var trackpadSessionScale: CGFloat = 1

  private func clamp(_ value: Double) -> Double {
    var v = value
    ClockFontSizeLimits.clampStoredFontSize(
      &v,
      style: .flip,
      screen: screen,
      config: config
    )
    return v
  }

  private func applyMagnificationScale(_ scale: CGFloat) {
    if pinchStartFontSize == nil {
      pinchStartFontSize = fontSize
    }
    guard let base = pinchStartFontSize else { return }
    fontSize = clamp(base * Double(scale))
  }

  private func endMagnificationSession() {
    pinchStartFontSize = nil
    trackpadSessionScale = 1
  }

  private func applyTrackpadDelta(_ delta: CGFloat) {
    guard enabled else { return }
    if pinchStartFontSize == nil {
      pinchStartFontSize = fontSize
      trackpadSessionScale = 1
    }
    trackpadSessionScale *= 1 + delta
    applyMagnificationScale(trackpadSessionScale)
  }

  func body(content: Content) -> some View {
    #if os(macOS)
      Group {
        if enabled {
          content
            .background {
              MacTrackpadMagnifyCaptureView(
                onMagnify: applyTrackpadDelta,
                onMagnifyEnded: endMagnificationSession
              )
              .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .contentShape(Rectangle())
        } else {
          content
        }
      }
    #else
      content
    #endif
  }
}

#if os(macOS)
  private struct MacTrackpadMagnifyCaptureView: NSViewRepresentable {
    let onMagnify: (CGFloat) -> Void
    let onMagnifyEnded: () -> Void

    func makeNSView(context: Context) -> MacTrackpadMagnifyCaptureNSView {
      let view = MacTrackpadMagnifyCaptureNSView()
      view.onMagnify = onMagnify
      view.onMagnifyEnded = onMagnifyEnded
      return view
    }

    func updateNSView(_ nsView: MacTrackpadMagnifyCaptureNSView, context: Context) {
      nsView.onMagnify = onMagnify
      nsView.onMagnifyEnded = onMagnifyEnded
    }
  }

  private final class MacTrackpadMagnifyCaptureNSView: NSView {
    var onMagnify: ((CGFloat) -> Void)?
    var onMagnifyEnded: (() -> Void)?

    private var endWorkItem: DispatchWorkItem?

    override var acceptsFirstResponder: Bool { true }

    override func magnify(with event: NSEvent) {
      onMagnify?(CGFloat(event.magnification))
      scheduleMagnifyEnded()
    }

    private func scheduleMagnifyEnded() {
      endWorkItem?.cancel()
      let work = DispatchWorkItem { [weak self] in
        self?.onMagnifyEnded?()
      }
      endWorkItem = work
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }
  }
#endif
