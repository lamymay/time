import Foundation
#if os(iOS)
  import UIKit
#elseif os(macOS)
  import AppKit
#endif

/// 仅在打开字体面板时加载；关闭后可释放以降低内存
enum FontCatalog {
  private static let builtIn = [
    "System Default", "System Monospaced", "System Rounded", "System Serif",
  ]

  @MainActor
  static func load() -> [String] {
    var loaded: [String] = []
    #if os(iOS)
      loaded = UIFont.familyNames
    #elseif os(macOS)
      loaded = NSFontManager.shared.availableFontFamilies
    #endif
    let combined = builtIn + loaded.sorted()
    var seen = Set<String>()
    return combined.filter { seen.insert($0).inserted }
  }
}
