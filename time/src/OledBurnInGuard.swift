import SwiftUI

/// 轻微周期性位移，降低 OLED 静态烧屏风险
struct OledBurnInGuardModifier: ViewModifier {
  var isEnabled: Bool
  var amplitude: CGFloat = 3.5

  func body(content: Content) -> some View {
    if isEnabled {
      TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
        let t = timeline.date.timeIntervalSinceReferenceDate
        let x = CGFloat(
          sin(t * 0.17) * Double(amplitude) + cos(t * 0.13) * Double(amplitude * 0.55)
        )
        let y = CGFloat(
          cos(t * 0.19) * Double(amplitude) + sin(t * 0.11) * Double(amplitude * 0.55)
        )
        content.offset(x: x, y: y)
      }
    } else {
      content
    }
  }
}

extension View {
  func oledBurnInGuard(isEnabled: Bool) -> some View {
    modifier(OledBurnInGuardModifier(isEnabled: isEnabled))
  }
}
