import SwiftUI

/// 将 `OledPixelShiftEngine` 的位移应用到时钟视图（DVD / 翻页共用）
struct OledPixelShiftModifier: ViewModifier {
  var engine: OledPixelShiftEngine
  var isEnabled: Bool
  var isActive: Bool
  var screenSize: CGSize

  func body(content: Content) -> some View {
    content
      .background(
        GeometryReader { geo in
          Color.clear
            .onAppear { engine.setContentSize(geo.size) }
            .onChange(of: geo.size) { _, size in
              engine.setContentSize(size)
            }
        }
      )
      .offset(
        x: isEnabled ? engine.offset.width : 0,
        y: isEnabled ? engine.offset.height : 0
      )
      .onAppear {
        engine.setScreenSize(screenSize)
        engine.setEnabled(isEnabled)
        engine.setActive(isActive)
      }
      .onChange(of: screenSize) { _, size in
        engine.setScreenSize(size)
      }
      .onChange(of: isEnabled) { _, enabled in
        engine.setEnabled(enabled)
      }
      .onChange(of: isActive) { _, active in
        engine.setActive(active)
      }
  }
}

extension View {
  func oledPixelShift(
    engine: OledPixelShiftEngine,
    isEnabled: Bool,
    isActive: Bool,
    screenSize: CGSize
  ) -> some View {
    modifier(
      OledPixelShiftModifier(
        engine: engine,
        isEnabled: isEnabled,
        isActive: isActive,
        screenSize: screenSize
      )
    )
  }
}
