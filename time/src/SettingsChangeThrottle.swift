import Foundation

/// 设置面板内合并高频写入，减轻 iOS 整页重绘
@MainActor
final class SettingsChangeThrottle {
  private var task: Task<Void, Never>?

  func schedule(delayNanoseconds: UInt64 = 120_000_000, action: @escaping () -> Void) {
    task?.cancel()
    task = Task {
      try? await Task.sleep(nanoseconds: delayNanoseconds)
      guard !Task.isCancelled else { return }
      action()
    }
  }

  func cancel() {
    task?.cancel()
    task = nil
  }

  func flush(action: @escaping () -> Void) {
    cancel()
    action()
  }
}
