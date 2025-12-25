import Combine
import SwiftUI

class ClockViewModel: ObservableObject {
  @Published var position: CGPoint? = nil
  @Published var clockColor: Color = .green
  @Published var currentTime = Date()
  @Published var totalSize: CGSize = .zero

  private var velocity: CGVector = CGVector(dx: 10, dy: 10)

  func updateVelocity(speed: Double) {
    // 保持当前方向，仅更新速率
    let currentDX = velocity.dx > 0 ? 1.0 : -1.0
    let currentDY = velocity.dy > 0 ? 1.0 : -1.0
    velocity = CGVector(
      dx: currentDX * 10 * CGFloat(speed),
      dy: currentDY * 10 * CGFloat(speed)
    )
  }

  func updatePosition(
    in screenSize: CGSize, isPickerOpen: Bool, pickerWidth: CGFloat, speed: Double
  ) {
    let effectiveWidth = isPickerOpen ? screenSize.width - pickerWidth : screenSize.width
    let effectiveHeight = screenSize.height

    guard totalSize.width > 0 else {
      position = CGPoint(x: effectiveWidth / 2, y: effectiveHeight / 2)
      return
    }

    let currentPos = position ?? CGPoint(x: effectiveWidth / 2, y: effectiveHeight / 2)

    // 边界碰撞检查：考虑时钟自身的尺寸（totalSize）
    let minX = totalSize.width / 2
    let maxX = effectiveWidth - (totalSize.width / 2)
    let minY = totalSize.height / 2
    let maxY = effectiveHeight - (totalSize.height / 2)

    var newX = currentPos.x + velocity.dx
    var newY = currentPos.y + velocity.dy

    if newX <= minX {
      newX = minX
      velocity.dx = abs(velocity.dx)
    } else if newX >= maxX {
      newX = maxX
      velocity.dx = -abs(velocity.dx)
    }

    if newY <= minY {
      newY = minY
      velocity.dy = abs(velocity.dy)
    } else if newY >= maxY {
      newY = maxY
      velocity.dy = -abs(velocity.dy)
    }

    position = CGPoint(x: newX, y: newY)
  }
}
