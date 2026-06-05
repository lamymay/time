import Foundation

#if os(macOS)
  import AppKit
#else
  import UIKit
#endif

enum FeedbackMailResult {
  case openedMailClient
  case copiedAddress
}

/// 打开系统邮件客户端；无可用邮箱客户端时复制地址到剪贴板
enum AppVersion {
  static var displayString: String {
    let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    return "\(short) (\(build))"
  }
}

enum FeedbackMail {
  static let developerEmail = "arcraydev@gmail.com"

  /// 尝试打开邮件客户端（预填收件人、主题、正文）
  static func requestFeedback(completion: @escaping (FeedbackMailResult) -> Void) {
    guard let url = feedbackMailURL() else {
      copyDeveloperEmail()
      completion(.copiedAddress)
      return
    }

    #if os(macOS)
      guard canOpenMailClient(for: url) else {
        copyDeveloperEmail()
        completion(.copiedAddress)
        return
      }
      DispatchQueue.main.async {
        if NSWorkspace.shared.open(url) {
          completion(.openedMailClient)
        } else {
          copyDeveloperEmail()
          completion(.copiedAddress)
        }
      }
    #else
      guard UIApplication.shared.canOpenURL(url) else {
        copyDeveloperEmail()
        completion(.copiedAddress)
        return
      }
      UIApplication.shared.open(url, options: [:]) { success in
        DispatchQueue.main.async {
          if success {
            completion(.openedMailClient)
          } else {
            copyDeveloperEmail()
            completion(.copiedAddress)
          }
        }
      }
    #endif
  }

  static func copyDeveloperEmail() {
    #if os(macOS)
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(developerEmail, forType: .string)
    #else
      UIPasteboard.general.string = developerEmail
    #endif
  }

  static var mailSubject: String { L10n.text("feedback.mail_subject") }

  private static func canOpenMailClient(for url: URL) -> Bool {
    #if os(macOS)
      NSWorkspace.shared.urlForApplication(toOpen: url) != nil
    #else
      UIApplication.shared.canOpenURL(url)
    #endif
  }

  private static func feedbackMailURL() -> URL? {
    var components = URLComponents()
    components.scheme = "mailto"
    components.path = developerEmail
    components.queryItems = [
      URLQueryItem(name: "subject", value: mailSubject),
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

  private static var appVersion: String { AppVersion.displayString }

  private static var platformDescription: String {
    #if os(macOS)
      let v = ProcessInfo.processInfo.operatingSystemVersion
      return "macOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    #else
      return "iOS \(UIDevice.current.systemVersion)"
    #endif
  }
}
