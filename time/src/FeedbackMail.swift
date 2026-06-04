import Foundation

#if os(macOS)
  import AppKit
#else
  import UIKit
#endif

/// 打开系统邮件客户端，向开发者发送反馈
enum FeedbackMail {
  static let developerEmail = "arcraydev@gmail.com"

  @discardableResult
  static func openFeedbackMail() -> Bool {
    guard let url = feedbackMailURL() else { return false }
    #if os(macOS)
      return NSWorkspace.shared.open(url)
    #else
      UIApplication.shared.open(url, options: [:], completionHandler: nil)
      return true
    #endif
  }

  private static func feedbackMailURL() -> URL? {
    var components = URLComponents()
    components.scheme = "mailto"
    components.path = developerEmail
    components.queryItems = [
      URLQueryItem(name: "subject", value: L10n.text("feedback.mail_subject")),
      URLQueryItem(name: "body", value: mailBody()),
    ]
    return components.url
  }

  private static func mailBody() -> String {
    String(
      format: L10n.text("feedback.mail_body"),
      appVersion,
      platformDescription
    )
  }

  private static var appVersion: String {
    let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    return "\(short) (\(build))"
  }

  private static var platformDescription: String {
    #if os(macOS)
      let v = ProcessInfo.processInfo.operatingSystemVersion
      return "macOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    #else
      return "iOS \(UIDevice.current.systemVersion)"
    #endif
  }
}
