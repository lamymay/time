import SwiftData
import SwiftUI

@main
struct TimeApp: App {
  // 使用通知中心来跨组件传递打开设置的指令
  let openSettingsNotification = NotificationCenter.default.publisher(
    for: NSNotification.Name("OpenSettings"))

  var body: some Scene {
    WindowGroup {
      ContentView()
        // 关键设置：使 Home Indicator 在无操作时自动隐藏
        .persistentSystemOverlays(.hidden)
        .onReceive(openSettingsNotification) { _ in
          // 发送信号给 ContentView 告知需要打开设置
          NotificationCenter.default.post(name: NSNotification.Name("ShowSettingsUI"), object: nil)
        }
    }
    .commands {
      // 替换系统的标准设置命令
      CommandGroup(replacing: .appSettings) {
        Button("设置...") {
          NotificationCenter.default.post(name: NSNotification.Name("ShowSettingsUI"), object: nil)
        }
        .keyboardShortcut(",", modifiers: .command)
      }
    }
  }
}
