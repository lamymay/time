//
//  timeUITestsLaunchTests.swift
//  timeUITests
//

import XCTest

final class timeUITestsLaunchTests: TimeUITestCase {

  override class var runsForEachTargetApplicationUIConfiguration: Bool {
    false
  }

  @MainActor
  func testLaunch_screenshot() throws {
    let app = launchTimeApp()
    _ = clockScene(in: app, timeout: 10)

    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = "Launch"
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
