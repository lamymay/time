import CoreGraphics
import Foundation

/// 临时调试：碰撞日志、边框高亮、撞墙后暂停 5s。截图完成后将 `isEnabled` 设为 `false`。
enum DVDCollisionDebug {
  static var isEnabled = true
  static let pauseDuration: TimeInterval = 5
  static let highlightLineWidth: CGFloat = 6

  static let collisionNotification = Notification.Name("DVDCollisionDebugDidHit")

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
    print(
      """
      [DVD Collision] \(edgeText)
        playfield: \(Int(event.playfieldSize.width))×\(Int(event.playfieldSize.height))
        clock center: (\(Int(event.clockCenter.x)), \(Int(event.clockCenter.y)))
        clock size: \(Int(event.clockSize.width))×\(Int(event.clockSize.height))
        pause \(Int(pauseDuration))s
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
