import CoreGraphics
import Foundation

/// 临时调试：碰撞日志、边框高亮、绿底、撞墙后暂停 3s。截图完成后将 `isEnabled` 设为 `false`。
enum DVDCollisionDebug {
  static var isEnabled = true
  static let pauseDuration: TimeInterval = 3
  static let highlightLineWidth: CGFloat = 6
  /// 碰撞瞬间背景高亮色
  static let hitBackgroundHex = "#1B8F3A"
  /// 紫框：CATextLayer 数字并集（可见字形区域）
  static let glyphBoundsBorderWidth: CGFloat = 2
  /// 橙框：碰撞用 UIView 整框（相对紫框多出的空白 = 不可见高度/宽度）
  static let collisionFrameBorderWidth: CGFloat = 1.5

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
    let right = event.clockCenter.x + event.clockSize.width / 2
    let bottom = event.clockCenter.y + event.clockSize.height / 2
    print(
      """
      [DVD Collision] \(edgeText)
        playfield: \(Int(event.playfieldSize.width))×\(Int(event.playfieldSize.height))
        clock center: (\(Int(event.clockCenter.x)), \(Int(event.clockCenter.y)))
        collision box: \(Int(event.clockSize.width))×\(Int(event.clockSize.height))
        extents: right=\(Int(right)) bottom=\(Int(bottom)) (limit w=\(Int(event.playfieldSize.width)) h=\(Int(event.playfieldSize.height)))
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
