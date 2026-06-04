import CoreGraphics

#if canImport(UIKit)
  import UIKit
#endif

enum ClockScreenBounds {
  /// 根 SwiftUI GeometryReader 在部分横屏场景会偏小，与 UIKit 窗口尺寸取较大值作为 DVD 弹跳区
  static func bouncePlayfield(swiftUISize: CGSize) -> CGSize {
    #if os(iOS)
      let window = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap(\.windows)
        .first { $0.isKeyWindow }?
        .bounds.size ?? .zero
      let w = max(swiftUISize.width, window.width)
      let h = max(swiftUISize.height, window.height)
      guard w > 1, h > 1 else { return swiftUISize }
      return CGSize(width: w, height: h)
    #else
      return swiftUISize
    #endif
  }
}
