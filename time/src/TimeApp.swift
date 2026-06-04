import SwiftUI

@main
struct TimeApp: App {
  let openSettingsNotification = NotificationCenter.default.publisher(
    for: NSNotification.Name("OpenSettings"))

  var body: some Scene {
    WindowGroup {
      ContentView()
        .persistentSystemOverlays(.hidden)
        .onReceive(openSettingsNotification) { _ in
          NotificationCenter.default.post(name: NSNotification.Name("ShowSettingsUI"), object: nil)
        }
    }
    .commands {
      CommandGroup(replacing: .appSettings) {
        Button("设置...") {
          NotificationCenter.default.post(name: NSNotification.Name("ShowSettingsUI"), object: nil)
        }
        .keyboardShortcut(",", modifiers: .command)
      }
    }
  }
}
