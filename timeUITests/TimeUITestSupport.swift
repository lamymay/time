//
//  TimeUITestSupport.swift
//  timeUITests
//

import XCTest

/// 与主工程 `TimeAccessibilityID` 保持同名同值
enum TimeUITestID {
  static let clockScene = "time.clock.scene"
  static let settingsPanel = "time.settings.panel"
  static let settingsBackdrop = "time.settings.backdrop"
  static let settingsCloseButton = "time.settings.close"
  static let settingsDoneButton = "time.settings.done"
}

enum TimeUITestLaunch {
  static let uiTesting = "-UITesting"
  static let openSettings = "-open-settings"
}

private let appBundleID = "com.arc.time"

/// 共享启动/收尾，避免用例间残留进程导致 launch 超时
class TimeUITestCase: XCTestCase {
  private(set) var app: XCUIApplication?

  override func setUpWithError() throws {
    try super.setUpWithError()
    continueAfterFailure = false
    Self.forceQuitDebugTimeAppIfNeeded()
    if Self.hasSuspendedDebugTimeProcess() {
      throw XCTSkip(
        "检测到 Xcode 调试中且已暂停的 time 进程。请先在 Xcode 点 Stop，再运行 UI 测试。"
      )
    }
  }

  override func tearDownWithError() throws {
    if let app {
      quitAppWithoutFailingTest(app)
    }
    app = nil
    try super.tearDownWithError()
  }

  @discardableResult
  func launchTimeApp(openSettings: Bool = false) -> XCUIApplication {
    Self.forceQuitDebugTimeAppIfNeeded()
    let app = XCUIApplication()
    var args = [TimeUITestLaunch.uiTesting]
    if openSettings {
      args.append(TimeUITestLaunch.openSettings)
    }
    app.launchArguments = args
    app.launch()
    self.app = app
    return app
  }

  /// 全屏/常亮时 `XCUIApplication.terminate()` 可能失败并拖垮用例；用 pkill 收尾且不记为断言失败
  private func quitAppWithoutFailingTest(_ app: XCUIApplication) {
    guard app.state != .notRunning else { return }
    app.terminate()
    if app.wait(for: .notRunning, timeout: 6) { return }
    Self.forceQuitDebugTimeAppIfNeeded()
    _ = app.wait(for: .notRunning, timeout: 4)
  }

  #if os(macOS)
    private static func forceQuitDebugTimeAppIfNeeded() {
      let proc = Process()
      proc.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
      proc.arguments = ["-9", "-f", "time.app/Contents/MacOS/time"]
      try? proc.run()
      proc.waitUntilExit()
      Thread.sleep(forTimeInterval: 0.25)
    }

    /// 调试器暂停（SX）时 pkill 无效，继续 launch 会卡 60s
    private static func hasSuspendedDebugTimeProcess() -> Bool {
      let proc = Process()
      proc.executableURL = URL(fileURLWithPath: "/usr/bin/ps")
      proc.arguments = ["-ax", "-o", "state=,command="]
      let pipe = Pipe()
      proc.standardOutput = pipe
      try? proc.run()
      proc.waitUntilExit()
      guard let text = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
      else { return false }
      for line in text.split(separator: "\n") {
        let s = String(line)
        guard s.contains("time.app/Contents/MacOS/time") else { continue }
        if s.hasPrefix("SX") || s.hasPrefix("T") || s.contains(" SX") { return true }
      }
      return false
    }
  #else
    private static func forceQuitDebugTimeAppIfNeeded() {}
  #endif

  func clockScene(in app: XCUIApplication, timeout: TimeInterval = 8) -> XCUIElement {
    let scene = app.descendants(matching: .any)[TimeUITestID.clockScene]
    XCTAssertTrue(scene.waitForExistence(timeout: timeout), "时钟主界面应可见")
    return scene
  }

  func settingsPanel(in app: XCUIApplication, timeout: TimeInterval = 5) -> XCUIElement {
    let panel = app.descendants(matching: .any)[TimeUITestID.settingsPanel]
    XCTAssertTrue(panel.waitForExistence(timeout: timeout), "设置面板应可见")
    return panel
  }

  func focusAppForKeyboard(in app: XCUIApplication) {
    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 6))
    app.activate()
    let scene = clockScene(in: app)
    if scene.isHittable {
      scene.click()
    } else {
      app.windows.firstMatch.click()
    }
  }

  #if os(macOS)
    func openSettingsWithKeyboard(in app: XCUIApplication) {
      focusAppForKeyboard(in: app)
      app.typeKey(",", modifierFlags: .command)
    }

    func dismissSettingsByTappingBackdrop(in app: XCUIApplication) {
      let backdrop = app.descendants(matching: .any)[TimeUITestID.settingsBackdrop]
      XCTAssertTrue(backdrop.waitForExistence(timeout: 4), "设置背板应可见")
      backdrop.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.5)).tap()
    }
  #endif

  func closeSettings(in app: XCUIApplication) {
    #if os(iOS)
      let done = app.buttons[TimeUITestID.settingsDoneButton]
      if done.waitForExistence(timeout: 2) {
        done.tap()
        return
      }
    #endif
    let close = app.buttons[TimeUITestID.settingsCloseButton]
    XCTAssertTrue(close.waitForExistence(timeout: 4), "设置关闭按钮应可见")
    close.tap()
  }

  func assertSettingsDismissed(in app: XCUIApplication, timeout: TimeInterval = 5) {
    let panel = app.descendants(matching: .any)[TimeUITestID.settingsPanel]
    XCTAssertTrue(panel.waitForNonExistence(timeout: timeout), "设置面板应已关闭")
  }
}
