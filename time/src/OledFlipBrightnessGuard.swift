#if os(iOS)
  import UIKit

  /// 翻页模式防烧屏：仅当系统亮度超过 80% 且拉满 5 分钟后，自动降到 80%
  enum OledFlipBrightnessGuard {
    /// 视为「系统最高亮度」的下限（UIScreen.brightness 0…1）
    static let maxBrightnessThreshold: CGFloat = 0.98
    /// 拉满后降至目标亮度（最大亮度的 80%）
    static let dimTargetBrightness: CGFloat = 0.8
    /// 未超过此亮度时不启动策略
    static let strategyFloorBrightness: CGFloat = 0.8
    static let holdDuration: TimeInterval = 5 * 60

    private static var isMonitoring = false
    private static var scheduledDim: DispatchWorkItem?
    private static var brightnessObserver: NSObjectProtocol?
    private static var isApplyingProgrammaticDim = false

    static func sync(
      flipMode: Bool,
      burnInProtectionEnabled: Bool,
      appActive: Bool,
      settingsOpen: Bool
    ) {
      let shouldMonitor =
        flipMode
        && burnInProtectionEnabled
        && appActive
        && !settingsOpen
        && !AppUITestConfig.isEnabled
      setMonitoring(shouldMonitor)
    }

    // MARK: - Monitoring

    private static func setMonitoring(_ enabled: Bool) {
      guard enabled != isMonitoring else {
        if enabled { evaluateBrightness() }
        return
      }
      isMonitoring = enabled
      if enabled {
        registerBrightnessObserver()
        evaluateBrightness()
      } else {
        unregisterBrightnessObserver()
        cancelScheduledDim()
      }
    }

    private static func registerBrightnessObserver() {
      guard brightnessObserver == nil else { return }
      brightnessObserver = NotificationCenter.default.addObserver(
        forName: UIScreen.brightnessDidChangeNotification,
        object: nil,
        queue: .main
      ) { _ in
        evaluateBrightness()
      }
    }

    private static func unregisterBrightnessObserver() {
      if let brightnessObserver {
        NotificationCenter.default.removeObserver(brightnessObserver)
        self.brightnessObserver = nil
      }
    }

    // MARK: - Policy

    private static func evaluateBrightness() {
      guard isMonitoring else { return }
      guard !isApplyingProgrammaticDim else { return }

      let brightness = UIScreen.main.brightness
      let current = CGFloat(brightness)

      if current <= strategyFloorBrightness {
        cancelScheduledDim()
        return
      }

      if current >= maxBrightnessThreshold {
        scheduleDimAfterHold()
      } else {
        cancelScheduledDim()
      }
    }

    private static func scheduleDimAfterHold() {
      guard scheduledDim == nil else { return }
      let work = DispatchWorkItem {
        scheduledDim = nil
        applyDimIfStillAtMax()
      }
      scheduledDim = work
      DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration, execute: work)
    }

    private static func cancelScheduledDim() {
      scheduledDim?.cancel()
      scheduledDim = nil
    }

    private static func applyDimIfStillAtMax() {
      guard isMonitoring else { return }
      let current = CGFloat(UIScreen.main.brightness)
      guard current >= maxBrightnessThreshold else { return }

      isApplyingProgrammaticDim = true
      UIScreen.main.brightness = dimTargetBrightness
      DispatchQueue.main.async {
        isApplyingProgrammaticDim = false
        evaluateBrightness()
      }
    }
  }
#endif
