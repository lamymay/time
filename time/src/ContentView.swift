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
}

/// 屏保级：原生 CATextLayer + layer transform 弹跳；无 NSHostingView
struct MotionClockScene: View {
  @State private var motion = ClockMotionEngine()
  let scheduler: ClockTimeScheduler
  let style: NativeClockStyle
  let precision: TimeDisplayPrecision
  let timeZoneTopGap: CGFloat
  let showTimeZoneText: Bool
  let screenSize: CGSize
  let moveSpeed: Double
  let isActive: Bool
  let isPaused: Bool
  let backgroundColorHex: String

  var body: some View {
    MotionClockContent(
      scheduler: scheduler,
      motion: motion,
      style: style,
      precision: precision,
      timeZoneTopGap: timeZoneTopGap,
      showTimeZoneText: showTimeZoneText,
      screenSize: screenSize,
      moveSpeed: moveSpeed,
      isActive: isActive,
      isPaused: isPaused,
      backgroundColorHex: backgroundColorHex
    )
  }
}

/// 使用 @Bindable 传入 engine；弹跳位移不再暴露 offset 属性
private struct MotionClockContent: View {
  let scheduler: ClockTimeScheduler
  @Bindable var motion: ClockMotionEngine
  let style: NativeClockStyle
  let precision: TimeDisplayPrecision
  let timeZoneTopGap: CGFloat
  let showTimeZoneText: Bool
  let screenSize: CGSize
  let moveSpeed: Double
  let isActive: Bool
  let isPaused: Bool
  let backgroundColorHex: String

  private var styleStamp: ClockStyleStamp {
    ClockStyleStamp(
      style: style,
      precision: precision,
      timeZoneTopGap: timeZoneTopGap,
      color: motion.clockColor,
      showTimeZoneText: showTimeZoneText
    )
  }

  var body: some View {
    BouncingClockHost(scheduler: scheduler, motion: motion, styleStamp: styleStamp)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onAppear {
      motion.setScreenSize(screenSize)
      motion.setMoveSpeed(moveSpeed)
      motion.setPaused(isPaused)
      motion.setMotionActive(isActive)
      motion.applyBackground(hex: backgroundColorHex)
    }
    .onChange(of: backgroundColorHex) { _, hex in
      motion.applyBackground(hex: hex)
    }
    .onChange(of: screenSize) { _, newSize in
      motion.setScreenSize(newSize)
    }
    .onChange(of: moveSpeed) { _, newSpeed in
      motion.setMoveSpeed(newSpeed)
    }
    .onChange(of: isActive) { _, active in
      motion.setMotionActive(active)
    }
    .onChange(of: isPaused) { _, paused in
      motion.setPaused(paused)
    }
  }
}

// MARK: - 根视图

struct ContentView: View {
  @AppStorage("moveSpeed") private var moveSpeed: Double = 0.09
  @AppStorage("fontSize") private var fontSize: Double = 214
  @AppStorage("padZero") private var padZero: Bool = false
  @AppStorage("is24Hour") private var is24Hour: Bool = false
  @AppStorage("showAMPM") private var showAMPM: Bool = true
  @AppStorage("ampmScale") private var ampmScale: Double = 0.25
  @AppStorage("ampmSide") private var ampmSide: String = "Leading"
  @AppStorage("selectedTimeZone") private var selectedTimeZone: String = TimeZone.current.identifier
  @AppStorage("showTimeZoneText") private var showTimeZoneText: Bool = true
  @AppStorage("selectedFontName") private var selectedFontName: String = "System Monospaced"
  @AppStorage("showDebugInfo") private var showDebugInfo: Bool = false
  @AppStorage("backgroundColorHex") private var backgroundColorHex: String = BackgroundColorPreset.black
    .rawValue
  @AppStorage("timeDisplayPrecision") private var timeDisplayPrecisionRaw: String =
    TimeDisplayPrecision.minute.rawValue
  @AppStorage("keepDisplayAwake") private var keepDisplayAwake = true
  @AppStorage("clockDisplayStyle") private var clockDisplayStyleRaw: String =
    ClockDisplayStyle.classic.rawValue

  @State private var timeScheduler = ClockTimeScheduler()
  @State private var showSettings = false
  @State private var showFontPicker = false
  @State private var fontCatalog: [String]?
  @State private var settingsPanelOffset: CGSize = .zero
  @Environment(\.scenePhase) private var scenePhase

  private var timeDisplayPrecision: TimeDisplayPrecision {
    TimeDisplayPrecision.resolved(fromRaw: timeDisplayPrecisionRaw)
  }

  private var clockConfig: ClockDisplayConfig {
    ClockDisplayConfig(
      fontSize: fontSize,
      padZero: padZero,
      is24Hour: is24Hour,
      showAMPM: showAMPM,
      ampmScale: ampmScale,
      ampmSide: ampmSide,
      selectedTimeZone: selectedTimeZone,
      showTimeZoneText: showTimeZoneText,
      selectedFontName: selectedFontName,
      displayPrecision: timeDisplayPrecision
    )
  }

  private var clockDisplayStyle: ClockDisplayStyle {
    ClockDisplayStyle(rawValue: clockDisplayStyleRaw) ?? .classic
  }

  private var clockStyle: NativeClockStyle {
    NativeClockStyle.resolve(fontSize: fontSize, ampmScale: ampmScale, fontName: selectedFontName)
  }

  var body: some View {
    GeometryReader { screenGeo in
      let uiSidePanelWidth: CGFloat = screenGeo.size.width > 600 ? 300 : screenGeo.size.width * 0.7

      ZStack(alignment: .topLeading) {
        Color(hex: backgroundColorHex)
          .ignoresSafeArea()
          .contentShape(Rectangle())
          .onTapGesture {
            withAnimation {
              showSettings = false
              showFontPicker = false
            }
          }
          .onLongPressGesture(minimumDuration: 0.5) {
            #if os(iOS)
              toggleSettings()
            #endif
          }
          #if os(macOS)
            .contextMenu {
              Button(L10n.text("menu.settings")) { toggleSettings() }
              Divider()
              Button(L10n.text("menu.quit")) { NSApplication.shared.terminate(nil) }
            }
          #endif

        clockScene(
          screenSize: screenGeo.size,
          isPaused: showSettings || showFontPicker
        )

        if showDebugInfo {
          debugOverlayView
        }

        if showSettings {
          settingsOverlay(size: screenGeo.size)
            .zIndex(100)
            .transition(settingsTransition(isWide: screenGeo.size.width > 600))
        }

        if showFontPicker {
          fontPickerOverlay(size: screenGeo.size, panelWidth: uiSidePanelWidth)
            .zIndex(200)
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }

        Button(action: toggleSettings) { Color.clear.frame(width: 1, height: 1) }
          .keyboardShortcut(",", modifiers: .command)
          .buttonStyle(.plain)
      }
      .onAppear {
        if timeDisplayPrecisionRaw == "millisecond" {
          timeDisplayPrecisionRaw = TimeDisplayPrecision.second.rawValue
        }
        syncTimeScheduler()
        timeScheduler.setActive(scenePhase == .active)
        DisplayKeepAwake.setEnabled(keepDisplayAwake)
      }
      .onChange(of: scenePhase) { _, phase in
        timeScheduler.setActive(phase == .active)
      }
      .onChange(of: keepDisplayAwake) { _, enabled in
        DisplayKeepAwake.setEnabled(enabled)
      }
      .onChange(of: clockConfig) { _, _ in
        syncTimeScheduler()
      }
      .onChange(of: clockDisplayStyleRaw) { _, _ in
        showFontPicker = false
      }
      .onChange(of: showFontPicker) { _, show in
        if show {
          if fontCatalog == nil { fontCatalog = FontCatalog.load() }
        } else {
          fontCatalog = nil
        }
      }
    }
  }

  private func syncTimeScheduler() {
    timeScheduler.setFormat(clockConfig.formatOptions)
  }

  @ViewBuilder
  private func clockScene(screenSize: CGSize, isPaused: Bool) -> some View {
    switch clockDisplayStyle {
    case .classic:
      MotionClockScene(
        scheduler: timeScheduler,
        style: clockStyle,
        precision: timeDisplayPrecision,
        timeZoneTopGap: -fontSize * 0.062,
        showTimeZoneText: showTimeZoneText,
        screenSize: screenSize,
        moveSpeed: moveSpeed,
        isActive: scenePhase == .active,
        isPaused: isPaused,
        backgroundColorHex: backgroundColorHex
      )
    case .flip:
      FlipClockScene(
        scheduler: timeScheduler,
        config: clockConfig,
        backgroundColorHex: backgroundColorHex,
        isActive: scenePhase == .active
      )
    }
  }

  private func settingsTransition(isWide: Bool) -> AnyTransition {
    if isWide {
      return .move(edge: .trailing).combined(with: .opacity)
    }
    return .move(edge: .bottom).combined(with: .opacity)
  }

  @ViewBuilder
  private func settingsOverlay(size: CGSize) -> some View {
    let isWide = size.width > 600

    ZStack(alignment: isWide ? .trailing : .bottom) {
      Color.black.opacity(0.48)
        .ignoresSafeArea()
        .onTapGesture {
          withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            showSettings = false
          }
        }

      settingsPanelView(layout: isWide ? .sidePanel : .bottomSheet)
        .frame(
          width: isWide ? min(400, size.width * 0.38) : nil,
          height: isWide ? nil : min(size.height * 0.88, 720)
        )
        .frame(maxWidth: isWide ? nil : .infinity)
        .padding(isWide ? EdgeInsets(top: 20, leading: 0, bottom: 20, trailing: 20) : EdgeInsets(top: 0, leading: 12, bottom: 12, trailing: 12))
    }
  }

  @ViewBuilder
  private func fontPickerOverlay(size: CGSize, panelWidth: CGFloat) -> some View {
    ZStack(alignment: .trailing) {
      Color.black.opacity(0.48)
        .ignoresSafeArea()
        .onTapGesture {
          withAnimation { showFontPicker = false }
        }

      Group {
        if let fontCatalog {
          SideFontPickerView(
            isPresented: $showFontPicker,
            selectedFontName: $selectedFontName,
            allFonts: fontCatalog
          )
        } else {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task { fontCatalog = FontCatalog.load() }
        }
      }
      .frame(width: panelWidth)
      .padding(.vertical, 20)
      .padding(.trailing, 20)
    }
  }

  private func settingsPanelView(layout: SettingsPanelLayout) -> some View {
    SettingsPanelView(
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
      keepDisplayAwake: $keepDisplayAwake,
      layout: layout,
      panelOffset: $settingsPanelOffset,
      onSpeedChange: {}
    )
  }

  private var debugOverlayView: some View {
    TimelineView(.periodic(from: .now, by: timeDisplayPrecision.debugTimelineInterval)) { timeline in
      VStack(alignment: .leading, spacing: 4) {
        Text(
          String(
            format: L10n.text("debug.system_format"),
            TimeProvider.formatSystemTime(from: timeline.date, precision: timeDisplayPrecision)
          )
        )
        Text(
          String(
            format: L10n.text("debug.logic_format"),
            String(is24Hour),
            selectedFontName
          )
        )
      }
      .font(.system(size: 10, design: .monospaced))
      .foregroundColor(.green.opacity(0.9))
      .padding(10).background(Color.black.opacity(0.4)).padding(10).zIndex(50)
    }
  }

  private func toggleSettings() {
    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
      showSettings.toggle()
      if showSettings { showFontPicker = false }
    }
  }
}
