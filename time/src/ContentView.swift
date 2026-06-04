import SwiftUI

struct ClockDisplayConfig: Equatable {
  var fontSize: Double
  var padZero: Bool
  var is24Hour: Bool
  var showAMPM: Bool
  var ampmScale: Double
  var ampmSide: String
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

  /// 压缩版右下角秒开启时，走时按秒调度（与 DVD 秒精度一致）
  var schedulerFormatOptions: ClockFormatOptions {
    var options = formatOptions
    if flipFormat == .compactPanels, flipCompactDetachedSeconds {
      options.displayPrecision = .second
    }
    return options
  }

  var showsLiveSeconds: Bool {
    displayPrecision.includesSeconds
      || (flipFormat == .compactPanels && flipCompactDetachedSeconds)
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
  @AppStorage("selectedTimeZone") private var selectedTimeZone: String = TimeZone.current.identifier
  @AppStorage("showTimeZoneText") private var showTimeZoneText: Bool = false
  @AppStorage("selectedFontName") private var selectedFontName: String = "System Monospaced"
  @AppStorage("showDebugInfo") private var showDebugInfo: Bool = false
  @AppStorage("backgroundColorHex") private var backgroundColorHex: String = BackgroundColorPreset.black
    .rawValue
  @AppStorage("timeDisplayPrecision") private var timeDisplayPrecisionRaw: String =
    TimeDisplayPrecision.minute.rawValue
  @AppStorage("keepDisplayAwake") private var keepDisplayAwake = true
  @AppStorage("oledPixelShiftEnabled") private var oledPixelShiftEnabled = true
  @AppStorage("clockDisplayStyle") private var clockDisplayStyleRaw: String =
    ClockDisplayStyle.flip.rawValue
  @AppStorage("clockColorHex") private var clockColorHex: String = ClockColorPreset.mint.rawValue
  @AppStorage("flipClockFormat") private var flipClockFormatRaw: String =
    FlipClockFormat.compactPanels.rawValue
  @AppStorage("flipCompactDetachedSeconds") private var flipCompactDetachedSeconds = true

  @State private var timeScheduler = ClockTimeScheduler()
  @State private var showSettings = false
  @State private var showFontPicker = false
  @State private var fontCatalog: [String]?
  @State private var settingsPanelOffset: CGSize = .zero
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
        showTimeZoneText: $showTimeZoneText,
        selectedTimeZone: $selectedTimeZone,
        showSettings: $showSettings,
        showFontPicker: $showFontPicker,
        showDebugInfo: $showDebugInfo,
        selectedFontName: $selectedFontName,
        backgroundColorHex: $backgroundColorHex,
        timeDisplayPrecisionRaw: $timeDisplayPrecisionRaw,
        clockDisplayStyleRaw: $clockDisplayStyleRaw,
        flipClockFormatRaw: $flipClockFormatRaw,
        flipCompactDetachedSeconds: $flipCompactDetachedSeconds,
        clockColorHex: $clockColorHex,
        keepDisplayAwake: $keepDisplayAwake,
        oledPixelShiftEnabled: $oledPixelShiftEnabled,
        settingsPanelOffset: $settingsPanelOffset,
        fontCatalog: $fontCatalog,
        flipLaunchPresentationApplied: $flipLaunchPresentationApplied,
        timeScheduler: timeScheduler,
        scenePhase: scenePhase
      )
      .onChange(of: geo.size.width) { _, _ in
        clampFontSize(for: geo.size)
      }
      .onChange(of: geo.size.height) { _, _ in
        clampFontSize(for: geo.size)
      }
    }
  }

  private func clampFontSize(for screen: CGSize) {
    let layout = layoutSize(for: screen)
    let precision = TimeDisplayPrecision.resolved(fromRaw: timeDisplayPrecisionRaw)
    let style = ClockDisplayStyle(rawValue: clockDisplayStyleRaw) ?? .classic
    let config = ClockDisplayConfig(
      fontSize: fontSize,
      padZero: padZero,
      is24Hour: is24Hour,
      showAMPM: showAMPM,
      ampmScale: ampmScale,
      ampmSide: ampmSide,
      selectedTimeZone: selectedTimeZone,
      showTimeZoneText: showTimeZoneText,
      selectedFontName: selectedFontName,
      displayPrecision: precision,
      flipFormat: FlipClockFormat.resolved(fromRaw: flipClockFormatRaw),
      flipCompactDetachedSeconds: flipCompactDetachedSeconds
    )
    let limitScreen = style == .flip ? screen : layout
    ClockFontSizeLimits.clampStoredFontSize(&fontSize, style: style, screen: limitScreen, config: config)
  }

  private func layoutSize(for screen: CGSize) -> CGSize {
    guard screen.width > 0 else { return screen }
    var width = screen.width
    if showSettings, screen.width > 600 {
      width -= min(400, screen.width * 0.38) + 48
    } else if showSettings {
      width *= 0.92
    }
    if showFontPicker {
      let panel = screen.width > 600 ? CGFloat(300) : screen.width * 0.7
      width -= panel + 40
    }
    width = max(width, screen.width * 0.42)
    return CGSize(width: width, height: screen.height)
  }
}
