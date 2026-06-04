import SwiftUI

/// 临时调试：碰撞边高亮（红框）
struct DVDCollisionDebugOverlay: View {
  let playfieldSize: CGSize
  let edges: Set<DVDCollisionDebug.Edge>

  private let color = Color.red.opacity(0.92)

  var body: some View {
    ZStack(alignment: .topLeading) {
      if edges.contains(.top) {
        edgeBar(width: playfieldSize.width, height: DVDCollisionDebug.highlightLineWidth)
      }
      if edges.contains(.bottom) {
        edgeBar(width: playfieldSize.width, height: DVDCollisionDebug.highlightLineWidth)
          .offset(y: max(0, playfieldSize.height - DVDCollisionDebug.highlightLineWidth))
      }
      if edges.contains(.left) {
        edgeBar(width: DVDCollisionDebug.highlightLineWidth, height: playfieldSize.height)
      }
      if edges.contains(.right) {
        edgeBar(width: DVDCollisionDebug.highlightLineWidth, height: playfieldSize.height)
          .offset(x: max(0, playfieldSize.width - DVDCollisionDebug.highlightLineWidth))
      }
    }
    .frame(width: playfieldSize.width, height: playfieldSize.height)
    .allowsHitTesting(false)
  }

  private func edgeBar(width: CGFloat, height: CGFloat) -> some View {
    Rectangle()
      .fill(color)
      .shadow(color: color, radius: 8)
      .frame(width: width, height: height)
  }
}
