import SwiftUI

/// 将 `OledPixelShiftEngine` 的位移应用到时钟视图（DVD / 翻页共用）
struct OledPixelShiftModifier: ViewModifier {
  var engine: OledPixelShiftEngine
  var isEnabled: Bool
  var isActive: Bool
  var screenSize: CGSize

  func body(content: Content) -> some View {
    content
      .offset(
        x: isEnabled ? engine.offset.width : 0,
        y: isEnabled ? engine.offset.height : 0
      )
      .onAppear {
        engine.setScreenSize(screenSize)
        // 不用嵌套 GeometryReader（会读到小时钟 intrinsic 尺寸）；烧屏漂移按屏尺寸估算内容区
        let estimated = CGSize(
          width: min(screenSize.width * 0.72, screenSize.width - 32),
          height: min(screenSize.height * 0.28, screenSize.height - 32)
        )
        engine.setContentSize(estimated)
        engine.setEnabled(isEnabled)
        engine.setActive(isActive)
      }
      .onChange(of: screenSize) { _, size in
        engine.setScreenSize(size)
        let estimated = CGSize(
          width: min(size.width * 0.72, size.width - 32),
          height: min(size.height * 0.28, size.height - 32)
        )
        engine.setContentSize(estimated)
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
