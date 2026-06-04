//
//  timeUITests.swift
//  timeUITests
//

import XCTest

final class timeUITests: TimeUITestCase {

  @MainActor
  func testLaunch_showsClockScene() throws {
    let app = launchTimeApp()
    _ = clockScene(in: app)
  }

  @MainActor
  func testSettings_openAndClose() throws {
    let app: XCUIApplication
    #if os(iOS)
      app = launchTimeApp(openSettings: true)
      _ = clockScene(in: app)
    #else
      app = launchTimeApp()
      _ = clockScene(in: app)
      openSettingsWithKeyboard(in: app)
    #endif

    _ = settingsPanel(in: app)
    closeSettings(in: app)
    assertSettingsDismissed(in: app)
  }

  @MainActor
  func testSettings_launchOpensPanel() throws {
    let app = launchTimeApp(openSettings: true)
    _ = clockScene(in: app)
    _ = settingsPanel(in: app)
    closeSettings(in: app)
    assertSettingsDismissed(in: app)
  }

  #if os(macOS)
    @MainActor
    func testSettings_closeWithEscape() throws {
      let app = launchTimeApp()
      _ = clockScene(in: app)
      openSettingsWithKeyboard(in: app)
      _ = settingsPanel(in: app)

      focusAppForKeyboard(in: app)
      app.typeKey(.escape, modifierFlags: [])
      assertSettingsDismissed(in: app)
    }

    @MainActor
    func testSettings_dismissByTappingOutside() throws {
      let app = launchTimeApp()
      _ = clockScene(in: app)
      openSettingsWithKeyboard(in: app)
      _ = settingsPanel(in: app)

      dismissSettingsByTappingBackdrop(in: app)
      assertSettingsDismissed(in: app)
    }

    @MainActor
    func testFontSize_keyboardZoomKeepsClockVisible() throws {
      let app = launchTimeApp()
      let scene = clockScene(in: app)
      focusAppForKeyboard(in: app)
      app.typeKey("=", modifierFlags: .command)
      XCTAssertTrue(scene.waitForExistence(timeout: 2))
      app.typeKey("-", modifierFlags: .command)
      XCTAssertTrue(scene.exists)
    }
  #endif

  @MainActor
  func testClockScene_stillVisibleWhileSettingsOpen() throws {
    let app = launchTimeApp(openSettings: true)
    let scene = clockScene(in: app)
    _ = settingsPanel(in: app)
    XCTAssertTrue(scene.exists, "打开设置时时钟区域仍应存在（无蒙层压暗布局）")
  }
}
