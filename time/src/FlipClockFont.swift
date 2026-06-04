import SwiftUI

#if os(macOS)
  import AppKit
#else
  import UIKit
#endif

enum FlipClockFont {
  static func swiftUI(
    size: CGFloat,
    fontName: String,
    weight: PlatformFont.Weight = .bold
  ) -> Font {
    Font(PlatformFont.native(fontName, size: size, weight: weight))
  }
}
