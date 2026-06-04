import SwiftUI

#if os(macOS)
  import AppKit

  /// 屏保快捷键：Enter 全屏；Q / S / K 退出
  enum ClockKeyboardShortcuts {
    private static let quitKeys: Set<String> = ["q", "s", "k"]
    private static var monitor: Any?

    static func install() {
      guard monitor == nil else { return }
      monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
        handle(event) ? nil : event
      }
    }

    static func uninstall() {
      if let monitor {
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
      }
    }

    /// - Returns: `true` 表示已消费该按键
    private static func handle(_ event: NSEvent) -> Bool {
      guard NSApp.isActive else { return false }
      if event.modifierFlags.intersection([.command, .control, .option]).isEmpty == false {
        return false
      }
      if isTypingInTextField() { return false }

      let keyCode = event.keyCode
      if keyCode == 36 || keyCode == 76 {
        WindowFullscreen.toggle()
        return true
      }

      guard let ch = event.charactersIgnoringModifiers?.lowercased(), ch.count == 1 else {
        return false
      }
      if quitKeys.contains(ch) {
        NSApplication.shared.terminate(nil)
        return true
      }
      return false
    }

    private static func isTypingInTextField() -> Bool {
      guard let responder = NSApp.keyWindow?.firstResponder else { return false }
      return responder is NSTextView || responder is NSTextField
    }
  }

  enum WindowFullscreen {
    static func toggle() {
      guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
      window.toggleFullScreen(nil)
    }
  }

  /// 挂载到根视图以注册/注销本地按键监听
  struct ClockKeyboardMonitorView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
      let view = NSView(frame: .zero)
      context.coordinator.didInstall = true
      ClockKeyboardShortcuts.install()
      return view
    }

    func updateNSView(_: NSView, context: Context) {}

    static func dismantleNSView(_: NSView, coordinator: Coordinator) {
      if coordinator.didInstall {
        ClockKeyboardShortcuts.uninstall()
      }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
      var didInstall = false
    }
  }

  extension View {
    func clockKeyboardShortcuts() -> some View {
      background(ClockKeyboardMonitorView().frame(width: 0, height: 0))
    }
  }
#else
  extension View {
    func clockKeyboardShortcuts() -> some View { self }
  }
#endif
