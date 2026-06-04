#if os(macOS)
  import AppKit

  /// 全屏屏保退出时先离开全屏，避免 UI 测试 / 系统 terminate 卡住
  final class TimeAppDelegate: NSObject, NSApplicationDelegate {
    private var pendingTerminate = false

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
      guard !pendingTerminate else { return .terminateNow }
      guard let window = NSApp.keyWindow ?? NSApp.mainWindow,
        window.styleMask.contains(.fullScreen)
      else {
        return .terminateNow
      }
      pendingTerminate = true
      window.toggleFullScreen(nil)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak sender] in
        sender?.reply(toApplicationShouldTerminate: true)
      }
      return .terminateLater
    }
  }
#endif
