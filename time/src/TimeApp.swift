import SwiftUI

@main
struct TimeApp: App {
  #if os(macOS)
    @NSApplicationDelegateAdaptor(TimeAppDelegate.self) private var appDelegate
  #endif
  #if os(iOS)
    @UIApplicationDelegateAdaptor(TimeIOSAppDelegate.self) private var iosAppDelegate
  #endif

  let openSettingsNotification = NotificationCenter.default.publisher(
    for: NSNotification.Name("OpenSettings"))

  var body: some Scene {
    WindowGroup {
      ContentView()
        .hidePersistentSystemOverlaysIfAvailable()
        .onReceive(openSettingsNotification) { _ in
          NotificationCenter.default.post(name: NSNotification.Name("ShowSettingsUI"), object: nil)
        }
    }
    .commands {
      CommandGroup(replacing: .appSettings) {
        Button(L10n.text("settings.menu")) {
          NotificationCenter.default.post(name: NSNotification.Name("ShowSettingsUI"), object: nil)
        }
        .keyboardShortcut(",", modifiers: .command)
      }
    }
  }
}
