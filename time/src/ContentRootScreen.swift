import SwiftUI

/// 从 ContentView 拆出的主界面，减轻 body 类型检查压力
struct ContentRootScreen: View {
  let screenSize: CGSize

  @Binding var moveSpeed: Double
  @Binding var fontSize: Double
  @Binding var padZero: Bool
  @Binding var is24Hour: Bool
  @Binding var showAMPM: Bool
  @Binding var ampmScale: Double
  @Binding var ampmSide: String
  @Binding var showTimeZoneText: Bool
  @Binding var selectedTimeZone: String
  @Binding var showSettings: Bool
  @Binding var showFontPicker: Bool
  @Binding var showDebugInfo: Bool
  @Binding var selectedFontName: String
  @Binding var backgroundColorHex: String
  @Binding var timeDisplayPrecisionRaw: String
  @Binding var clockDisplayStyleRaw: String
  @Binding var flipClockFormatRaw: String
  @Binding var flipCompactDetachedSeconds: Bool
  @Binding var clockColorHex: String
  @Binding var keepDisplayAwake: Bool
  @Binding var settingsPanelOffset: CGSize
  @Binding var fontCatalog: [String]?
  @Binding var flipLaunchPresentationApplied: Bool

  var timeScheduler: ClockTimeScheduler
  var scenePhase: ScenePhase

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
      displayPrecision: timeDisplayPrecision,
      flipFormat: FlipClockFormat.resolved(fromRaw: flipClockFormatRaw),
      flipCompactDetachedSeconds: flipCompactDetachedSeconds
    )
  }

  private var clockDisplayStyle: ClockDisplayStyle {
    ClockDisplayStyle(rawValue: clockDisplayStyleRaw) ?? .classic
  }

  private var layoutSize: CGSize { clockLayoutSize(in: screenSize) }
  private var isWideLayout: Bool { screenSize.width > 600 }
  private var sidePanelWidth: CGFloat { screenSize.width > 600 ? 300 : screenSize.width * 0.7 }
  private var clockPaused: Bool { showSettings || showFontPicker }
  private var oledGuardEnabled: Bool { scenePhase == .active && !showSettings && !showFontPicker }

  var body: some View {
    panelClampLayer
  }

  private var panelClampLayer: some View {
    styleChangeLayer
      .onChange(of: showSettings) { _, _ in clampFontSizeToScreen() }
      .onChange(of: showFontPicker) { _, _ in clampFontSizeToScreen() }
  }

  private var styleChangeLayer: some View {
    configChangeLayer
      .onChange(of: clockDisplayStyleRaw) { _, _ in reactStyleChange() }
  }

  private var configChangeLayer: some View {
    sceneLifecycleLayer
      .onChange(of: fontSize) { _, _ in reactConfigChange() }
      .onChange(of: padZero) { _, _ in reactConfigChange() }
      .onChange(of: is24Hour) { _, _ in reactConfigChange() }
      .onChange(of: showAMPM) { _, _ in reactConfigChange() }
      .onChange(of: ampmSide) { _, _ in reactConfigChange() }
      .onChange(of: selectedTimeZone) { _, _ in reactConfigChange() }
      .onChange(of: showTimeZoneText) { _, _ in reactConfigChange() }
      .onChange(of: selectedFontName) { _, _ in reactConfigChange() }
      .onChange(of: timeDisplayPrecisionRaw) { _, _ in reactConfigChange() }
      .onChange(of: flipClockFormatRaw) { _, _ in reactConfigChange() }
      .onChange(of: flipCompactDetachedSeconds) { _, _ in reactConfigChange() }
  }

  private var sceneLifecycleLayer: some View {
    coreStack
      .onAppear(perform: handleAppear)
      .onChange(of: scenePhase) { _, phase in
        timeScheduler.setActive(phase == .active)
      }
      .onChange(of: keepDisplayAwake) { _, enabled in
        DisplayKeepAwake.setEnabled(enabled)
      }
      .clockKeyboardShortcuts()
      .background(fontSizeShortcutButtons)
      .onReceive(NotificationCenter.default.publisher(for: .clockAdjustFontSize)) { note in
        guard let delta = note.userInfo?["delta"] as? Double else { return }
        adjustFontSize(by: delta)
      }
      .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowSettingsUI"))) { _ in
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
          showSettings = true
          showFontPicker = false
        }
      }
  }

  private var coreStack: some View {
    ZStack(alignment: .topLeading) {
      backgroundLayer
      clockLayer
      overlayStack
      settingsShortcutButton
    }
  }

  private var fontSizeShortcutButtons: some View {
    Group {
      Button(action: { adjustFontSize(by: ClockFontSizeLimits.keyboardFontSizeStep) }) {
        Color.clear.frame(width: 0, height: 0)
      }
      .keyboardShortcut("=", modifiers: .command)
      .buttonStyle(.plain)

      Button(action: { adjustFontSize(by: ClockFontSizeLimits.keyboardFontSizeStep) }) {
        Color.clear.frame(width: 0, height: 0)
      }
      .keyboardShortcut("+", modifiers: .command)
      .buttonStyle(.plain)

      Button(action: { adjustFontSize(by: -ClockFontSizeLimits.keyboardFontSizeStep) }) {
        Color.clear.frame(width: 0, height: 0)
      }
      .keyboardShortcut("-", modifiers: .command)
      .buttonStyle(.plain)
    }
    .allowsHitTesting(false)
  }

  private var clockLayer: some View {
    clockScene(screenSize: layoutSize, isPaused: clockPaused)
      .accessibilityIdentifier(TimeAccessibilityID.clockScene)
      .accessibilityElement(children: .contain)
      .oledBurnInGuard(isEnabled: oledGuardEnabled)
  }

  @ViewBuilder
  private var overlayStack: some View {
    if showDebugInfo {
      debugOverlay
    }
    if showSettings {
      settingsOverlay(size: screenSize, isWide: isWideLayout)
        .zIndex(100)
        .transition(settingsTransition(isWide: isWideLayout))
    }
    if showFontPicker {
      fontPickerOverlay(size: screenSize, panelWidth: sidePanelWidth)
        .zIndex(200)
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }
  }

  // MARK: - Layers

  private var backgroundLayer: some View {
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
  }

  private var settingsShortcutButton: some View {
    Button(action: toggleSettings) { Color.clear.frame(width: 1, height: 1) }
      .keyboardShortcut(",", modifiers: .command)
      .buttonStyle(.plain)
  }

  // MARK: - Clock

  @ViewBuilder
  private func clockScene(screenSize: CGSize, isPaused: Bool) -> some View {
    switch clockDisplayStyle {
    case .classic:
      let style = classicClockStyle(screenSize: screenSize)
      MotionClockScene(
        scheduler: timeScheduler,
        style: style,
        precision: timeDisplayPrecision,
        timeZoneTopGap: -style.fontSize * 0.062,
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
        clockColorHex: clockColorHex,
        isActive: scenePhase == .active
      )
      .ignoresSafeArea()
    }
  }

  private func classicClockStyle(screenSize: CGSize) -> NativeClockStyle {
    let effective = ClockFontSizeLimits.classicEffectiveFontSize(
      configured: fontSize,
      screen: screenSize,
      config: clockConfig
    )
    return NativeClockStyle.resolve(
      fontSize: Double(effective),
      ampmScale: ampmScale,
      fontName: selectedFontName
    )
  }

  // MARK: - Overlays

  private func settingsTransition(isWide: Bool) -> AnyTransition {
    if isWide {
      return .move(edge: .trailing).combined(with: .opacity)
    }
    return .move(edge: .bottom).combined(with: .opacity)
  }

  @ViewBuilder
  private func settingsOverlay(size: CGSize, isWide: Bool) -> some View {
    ZStack(alignment: isWide ? .trailing : .bottom) {
      // 透明点击区：不关底层颜色，便于在菜单里预览背景/字体色
      Color.clear
        .contentShape(Rectangle())
        .ignoresSafeArea()
        .accessibilityIdentifier(TimeAccessibilityID.settingsBackdrop)
        .onTapGesture {
          withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            showSettings = false
          }
        }

      SettingsPanelView(
        screenSize: size,
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
        layout: isWide ? .sidePanel : .bottomSheet,
        panelOffset: $settingsPanelOffset,
        onSpeedChange: {}
      )
      .frame(
        width: isWide ? min(400, size.width * 0.38) : nil,
        height: isWide ? nil : min(size.height * 0.88, 720)
      )
      .frame(maxWidth: isWide ? nil : .infinity)
      .padding(
        isWide
          ? EdgeInsets(top: 20, leading: 0, bottom: 20, trailing: 20)
          : EdgeInsets(top: 0, leading: 12, bottom: 12, trailing: 12)
      )
    }
    #if os(macOS)
      .onExitCommand {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
          showSettings = false
        }
      }
    #endif
  }

  @ViewBuilder
  private func fontPickerOverlay(size: CGSize, panelWidth: CGFloat) -> some View {
    ZStack(alignment: .trailing) {
      Color.clear
        .contentShape(Rectangle())
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

  private var debugOverlay: some View {
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
      .padding(10)
      .background(Color.black.opacity(0.4))
      .padding(10)
      .zIndex(50)
    }
  }

  // MARK: - Actions

  private func toggleSettings() {
    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
      showSettings.toggle()
      if showSettings { showFontPicker = false }
    }
  }

  private func handleAppear() {
    if AppUITestConfig.isEnabled {
      clockDisplayStyleRaw = ClockDisplayStyle.classic.rawValue
      flipLaunchPresentationApplied = true
    }
    if timeDisplayPrecisionRaw == "millisecond" {
      timeDisplayPrecisionRaw = TimeDisplayPrecision.second.rawValue
    }
    timeScheduler.setFormat(clockConfig.schedulerFormatOptions)
    timeScheduler.setActive(scenePhase == .active)
    DisplayKeepAwake.setEnabled(keepDisplayAwake)
    if AppUITestConfig.openSettingsOnLaunch {
      showSettings = true
    }
    if clockDisplayStyle == .flip, !flipLaunchPresentationApplied {
      flipLaunchPresentationApplied = true
      applyFlipPresentation()
    } else {
      clampFontSizeToScreen()
    }
  }

  private func reactConfigChange() {
    timeScheduler.setFormat(clockConfig.schedulerFormatOptions)
    clampFontSizeToScreen()
  }

  private func adjustFontSize(by delta: Double) {
    fontSize += delta
    clampFontSizeToScreen()
  }

  private func reactStyleChange() {
    showFontPicker = false
    if clockDisplayStyle == .flip {
      applyFlipPresentation()
    } else {
      clampFontSizeToScreen()
    }
  }

  private func clampFontSizeToScreen() {
    let limitScreen =
      clockDisplayStyle == .flip ? screenSize : clockLayoutSize(in: screenSize)
    ClockFontSizeLimits.clampStoredFontSize(
      &fontSize,
      style: clockDisplayStyle,
      screen: limitScreen,
      config: clockConfig
    )
  }

  private func clockLayoutSize(in screen: CGSize) -> CGSize {
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

  private func applyFlipPresentation() {
    showSettings = false
    showFontPicker = false
    ClockFontSizeLimits.applyFlipMaximumFontSize(
      &fontSize,
      screen: screenSize,
      config: clockConfig
    )
    #if os(macOS)
      if !AppUITestConfig.skipFlipLaunchFullscreen {
        DispatchQueue.main.async {
          WindowFullscreen.enterIfNeeded()
        }
      }
    #endif
  }
}

#if os(macOS)
  import AppKit
#endif
