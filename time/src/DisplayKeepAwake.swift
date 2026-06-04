import Foundation
#if os(iOS)
  import UIKit
#elseif os(macOS)
  import IOKit.pwr_mgt
#endif

/// 屏保/常驻：防止系统自动熄屏（按设置开关）
enum DisplayKeepAwake {
  static func setEnabled(_ enabled: Bool) {
    #if os(iOS)
      UIApplication.shared.isIdleTimerDisabled = enabled
    #elseif os(macOS)
      setMacEnabled(enabled)
    #endif
  }

  #if os(macOS)
    private static var assertionID: IOPMAssertionID = 0

    private static func setMacEnabled(_ enabled: Bool) {
      if enabled {
        guard assertionID == 0 else { return }
        let reason = "time clock screensaver" as CFString
        IOPMAssertionCreateWithName(
          kIOPMAssertionTypeNoDisplaySleep as CFString,
          IOPMAssertionLevel(kIOPMAssertionLevelOn),
          reason,
          &assertionID
        )
      } else if assertionID != 0 {
        IOPMAssertionRelease(assertionID)
        assertionID = 0
      }
    }
  #endif
}
