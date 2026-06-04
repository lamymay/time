#if os(iOS)
  import UIKit

  /// 明确允许 iPhone 横屏（与 Info.plist 一致，避免多平台工程下被限制为竖屏）
  final class TimeIOSAppDelegate: NSObject, UIApplicationDelegate {
    func application(
      _ application: UIApplication,
      supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
      switch UIDevice.current.userInterfaceIdiom {
      case .pad:
        return .all
      default:
        return [.portrait, .landscapeLeft, .landscapeRight]
      }
    }
  }
#endif
