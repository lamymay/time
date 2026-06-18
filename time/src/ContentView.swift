import SwiftUI

struct ClockDisplayConfig: Equatable {
  var fontSize: Double
  var padZero: Bool
  var is24Hour: Bool
  var showAMPM: Bool
  var ampmScale: Double
  var ampmSide: String
  /// `Top` / `Bottom`，相对主时间块的垂直对齐
  var ampmVertical: String
  var selectedTimeZone: String
  var showTimeZoneText: Bool
  var selectedFontName: String
  var displayPrecision: TimeDisplayPrecision
  var flipFormat: FlipClockFormat
  /// 压缩秒版式：是否在分钟板右下独立显示秒（关则仅时+分两块）
  var flipCompactDetachedSeconds: Bool

  var formatOptions: ClockFormatOptions {
    ClockFormatOptions(
      is24Hour: is24Hour,
      padZero: padZero,
      showAMPM: showAMPM,
      ampmSide: ampmSide,
      showTimeZoneText: showTimeZoneText,
      timeZoneIdentifier: selectedTimeZone,
      displayPrecision: displayPrecision
    )
  }

  /// 按展示样式应用限制：翻页无时区、AM/PM 仅在前
  func formatOptions(for style: ClockDisplayStyle) -> ClockFormatOptions {
    var options = formatOptions
    guard style == .flip else { return options }
    options.showTimeZoneText = false
    options.ampmSide = "Leading"
    return options
  }

  /// 经典模式显示秒时，调度必须按秒 tick（与 stamp.precision 一致）
  func schedulerFormatOptions(for style: ClockDisplayStyle) -> ClockFormatOptions {
    var options = formatOptions(for: style)
    switch style {
    case .classic:
      if displayPrecision.includesSeconds {
        options.displayPrecision = .second
      }
    case .flip:
      if flipFormat == .compactPanels, showsFlipDetachedSeconds {
        options.displayPrecision = .second
      }
    }
    return options
  }

  func applyingDisplayStyle(_ style: ClockDisplayStyle) -> ClockDisplayConfig {
    var copy = self
    guard style == .flip else { return copy }
    copy.showTimeZoneText = false
    copy.ampmSide = "Leading"
    return copy
  }

  /// 三等分等大秒板 / 主时钟秒位
  var showsLiveSeconds: Bool {
    displayPrecision.includesSeconds
  }

  /// 压缩版右下秒：「秒」精度下压缩秒布局自带；「分」精度需手动开启
  var showsFlipDetachedSeconds: Bool {
    guard flipFormat == .compactPanels else { return false }
    return displayPrecision.includesSeconds || flipCompactDetachedSeconds
  }

  /// 指定样式下是否会显示秒（用于设置项预览）
  func showsSeconds(for style: ClockDisplayStyle) -> Bool {
    switch style {
    case .classic:
      return displayPrecision.includesSeconds
    case .flip:
      return showsLiveSeconds || showsFlipDetachedSeconds
    }
  }

  /// 翻页「分」精度：不可选三等分；独立秒开关保留
  static func clampFlipStorageForPrecision(
    precisionRaw: String,
    flipFormatRaw: inout String,
    flipCompactDetachedSeconds: inout Bool
  ) {
    guard !TimeDisplayPrecision.resolved(fromRaw: precisionRaw).includesSeconds else { return }
    if FlipClockFormat.resolved(fromRaw: flipFormatRaw) == .tripleEqual {
      flipFormatRaw = FlipClockFormat.compactPanels.rawValue
    }
  }
}

// MARK: - 根视图

struct ContentView: View {
  @AppStorage("moveSpeed") private var moveSpeed: Double = 0.09
  @AppStorage("fontSize") private var fontSize: Double = 214
  @AppStorage("padZero") private var padZero: Bool = false
  @AppStorage("is24Hour") private var is24Hour: Bool = true
  @AppStorage("showAMPM") private var showAMPM: Bool = true
  @AppStorage("ampmScale") private var ampmScale: Double = 0.25
  @AppStorage("ampmSide") private var ampmSide: String = "Leading"
  @AppStorage("ampmVertical") private var ampmVertical: String = "Top"
  @AppStorage("selectedTimeZone") private var selectedTimeZone: String = TimeZone.current.identifier
  @AppStorage("showTimeZoneText") private var showTimeZoneText: Bool = false
  @AppStorage("selectedFontName") private var selectedFontName: String = "System Monospaced"
  @AppStorage("showDebugInfo") private var showDebugInfo: Bool = false
  @AppStorage(DVDCollisionDebug.pauseSecondsKey) private var dvdCollisionDebugPauseSeconds: Double =
    DVDCollisionDebug.defaultPauseSeconds
  @AppStorage("backgroundColorHex") private var backgroundColorHex: String = BackgroundColorPreset.black
    .rawValue
  @AppStorage("timeDisplayPrecision") private var timeDisplayPrecisionRaw: String =
    TimeDisplayPrecision.minute.rawValue
  @AppStorage("keepDisplayAwake") private var keepDisplayAwake = true
  @AppStorage("oledPixelShiftEnabled") private var oledPixelShiftEnabled = true
  @AppStorage("clockDisplayStyle") private var clockDisplayStyleRaw: String =
    ClockDisplayStyle.flip.rawValue
  @AppStorage("fontColorHex") private var fontColorHex: String = ClockColorPreset.mint.rawValue
  /// 翻页数字方块底色（翻页色块）
  @AppStorage("flipCardColorHex") private var flipCardColorHex: String = "#46464C"
  @AppStorage("flipClockFormat") private var flipClockFormatRaw: String =
    FlipClockFormat.compactPanels.rawValue
  @AppStorage("flipCompactDetachedSeconds") private var flipCompactDetachedSeconds = true
  /// 刘海屏是否避让顶部安全区（左/右/底始终铺满）
  @AppStorage("avoidTopSafeAreaOnNotch") private var avoidTopSafeAreaOnNotch = false
  @AppStorage(ClockScreenLayout.notchTopContentInsetKey) private var notchTopContentInset: Double =
    Double(ClockScreenLayout.defaultNotchTopContentInset)

  @StateObject private var timeScheduler = ClockTimeScheduler()
  @State private var showSettings = false
  @State private var showFontPicker = false
  @State private var fontCatalog: [String]?
  @State private var settingsPanelOffset: CGSize = .zero
  /// iOS 底部设置面板宽度；0 = 自动（居中、最大约 420pt）
  @AppStorage("settingsSheetWidth") private var settingsSheetWidth: Double = 0
  @AppStorage("settingsPanelExpanded") private var settingsPanelExpanded = false
  @State private var flipLaunchPresentationApplied = false
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    GeometryReader { geo in
      ContentRootScreen(
        screenSize: geo.size,
        moveSpeed: $moveSpeed,
        fontSize: $fontSize,
        padZero: $padZero,
        is24Hour: $is24Hour,
        showAMPM: $showAMPM,
        ampmScale: $ampmScale,
        ampmSide: $ampmSide,
        ampmVertical: $ampmVertical,
        showTimeZoneText: $showTimeZoneText,
        selectedTimeZone: $selectedTimeZone,
        showSettings: $showSettings,
        showFontPicker: $showFontPicker,
        showDebugInfo: $showDebugInfo,
        dvdCollisionDebugPauseSeconds: $dvdCollisionDebugPauseSeconds,
        selectedFontName: $selectedFontName,
        backgroundColorHex: $backgroundColorHex,
        timeDisplayPrecisionRaw: $timeDisplayPrecisionRaw,
        clockDisplayStyleRaw: $clockDisplayStyleRaw,
        flipClockFormatRaw: $flipClockFormatRaw,
        flipCompactDetachedSeconds: $flipCompactDetachedSeconds,
        fontColorHex: $fontColorHex,
        flipCardColorHex: $flipCardColorHex,
        keepDisplayAwake: $keepDisplayAwake,
        oledPixelShiftEnabled: $oledPixelShiftEnabled,
        avoidTopSafeAreaOnNotch: $avoidTopSafeAreaOnNotch,
        notchTopContentInset: $notchTopContentInset,
        settingsPanelOffset: $settingsPanelOffset,
        settingsSheetWidth: $settingsSheetWidth,
        settingsPanelExpanded: $settingsPanelExpanded,
        fontCatalog: $fontCatalog,
        flipLaunchPresentationApplied: $flipLaunchPresentationApplied,
        timeScheduler: timeScheduler,
        scenePhase: scenePhase
      )
      .onAppear {
        migrateLegacyClockColorIfNeeded()
        ClockDisplayConfig.clampFlipStorageForPrecision(
          precisionRaw: timeDisplayPrecisionRaw,
          flipFormatRaw: &flipClockFormatRaw,
          flipCompactDetachedSeconds: &flipCompactDetachedSeconds
        )
      }
    }
    .fullScreenClockBleedIfAvailable()
  }

  private static let colorKeysMigratedKey = "colorKeysMigratedV2"

  /// 旧版 clockColorHex 表示数字色；拆分为 fontColorHex + flipCardColorHex 后迁移一次
  private func migrateLegacyClockColorIfNeeded() {
    guard !UserDefaults.standard.bool(forKey: Self.colorKeysMigratedKey) else { return }
    if UserDefaults.standard.object(forKey: "fontColorHex") == nil,
      let legacy = UserDefaults.standard.string(forKey: "clockColorHex")
    {
      fontColorHex = legacy
    }
    UserDefaults.standard.set(true, forKey: Self.colorKeysMigratedKey)
  }

}
