import CoreGraphics
import Foundation

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

/// DVD 碰撞调试：日志、紫框、撞墙绿底、可配置暂停（随设置「调试」开关启用）
enum DVDCollisionDebug {
  static let debugToggleKey = "showDebugInfo"
  static let pauseSecondsKey = "dvdCollisionDebugPauseSeconds"
  static let defaultPauseSeconds: TimeInterval = 3
  static let pauseSecondsRange: ClosedRange<Double> = 0...20

  static let hitBackgroundHex = "#1B8F3A"
  static let borderWidth: CGFloat = 1.5
  static let glyphBoundsBorderWidth: CGFloat = 2
  static let collisionFrameBorderWidth: CGFloat = 1.5

  static let collisionNotification = Notification.Name("DVDCollisionDebugDidHit")

  static var isEnabled: Bool {
    UserDefaults.standard.bool(forKey: debugToggleKey)
  }

  static var pauseDuration: TimeInterval {
    guard UserDefaults.standard.object(forKey: pauseSecondsKey) != nil else {
      return defaultPauseSeconds
    }
    let stored = UserDefaults.standard.double(forKey: pauseSecondsKey)
    return min(max(stored, pauseSecondsRange.lowerBound), pauseSecondsRange.upperBound)
  }

  static var borderCGColor: CGColor {
    #if os(iOS)
      UIColor.systemPurple.cgColor
    #else
      NSColor.systemPurple.cgColor
    #endif
  }

  enum Edge: String, CaseIterable, Hashable {
    case left
    case right
    case top
    case bottom

    var logLabel: String {
      switch self {
      case .left: "左边框 (left)"
      case .right: "右边框 (right)"
      case .top: "上边框 (top)"
      case .bottom: "下边框 (bottom)"
      }
    }
  }

  struct Event {
    let edges: Set<Edge>
    let playfieldSize: CGSize
    let clockCenter: CGPoint
    let clockSize: CGSize
  }

  static func logCollision(_ event: Event) {
    guard isEnabled else { return }
    let edgeText = event.edges.sorted { $0.rawValue < $1.rawValue }.map(\.logLabel).joined(separator: " + ")
    let right = event.clockCenter.x + event.clockSize.width / 2
    let bottom = event.clockCenter.y + event.clockSize.height / 2
    print(
      """
      [DVD Collision] \(edgeText)
        playfield: \(Int(event.playfieldSize.width))×\(Int(event.playfieldSize.height))
        clock center: (\(Int(event.clockCenter.x)), \(Int(event.clockCenter.y)))
        collision box: \(Int(event.clockSize.width))×\(Int(event.clockSize.height))
        extents: right=\(Int(right)) bottom=\(Int(bottom)) (limit w=\(Int(event.playfieldSize.width)) h=\(Int(event.playfieldSize.height)))
        pause \(String(format: "%.1f", pauseDuration))s
      """
    )
  }

  static func postCollision(_ event: Event) {
    guard isEnabled else { return }
    logCollision(event)
    NotificationCenter.default.post(
      name: collisionNotification,
      object: nil,
      userInfo: [
        "edgeNames": event.edges.map(\.rawValue),
        "playfieldWidth": event.playfieldSize.width,
        "playfieldHeight": event.playfieldSize.height,
      ]
    )
  }
}
