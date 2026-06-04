import SwiftUI

#if os(macOS)
  import AppKit
#else
  import UIKit
#endif

enum FlipClockFont {
  static func swiftUI(size: CGFloat, fontName: String) -> Font {
    #if os(macOS)
      Font(PlatformFont.native(fontName, size: size, weight: .bold))
    #else
      Font(PlatformFont.native(fontName, size: size, weight: .bold))
    #endif
  }
}
