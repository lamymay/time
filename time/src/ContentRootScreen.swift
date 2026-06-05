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
  @Binding var dvdCollisionDebugPauseSeconds: Double
  @Binding var selectedFontName: String
  @Binding var backgroundColorHex: String
  @Binding var timeDisplayPrecisionRaw: String
  @Binding var clockDisplayStyleRaw: String
  @Binding var flipClockFormatRaw: String
  @Binding var flipCompactDetachedSeconds: Bool
  @Binding var fontColorHex: String
  @Binding var flipCardColorHex: String
  @Binding var keepDisplayAwake: Bool
  @Binding var oledPixelShiftEnabled: Bool
  @Binding var avoidTopSafeAreaOnNotch: Bool
  @Binding var notchTopInsetTighten: Double
  @Binding var settingsPanelOffset: CGSize
  @Binding var settingsSheetWidth: Double
  @Binding var fontCatalog: [String]?
  @Binding var flipLaunchPresentationApplied: Bool

  @ObservedObject var timeScheduler: ClockTimeScheduler
  var scenePhase: ScenePhase

  @StateObject private var oledPixelShift = OledPixelShiftEngine()
  @State private var dvdCollisionDebugHit = false

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

  private var clockTopInset: CGFloat {
    ClockScreenLayout.resolvedTopClockInset(avoidTopSafeAreaOnNotch: avoidTopSafeAreaOnNotch)
  }

  private var clockPlayfieldSize: CGSize {
    CGSize(width: screenSize.width, height: max(screenSize.height - clockTopInset, 1))
  }

  private var layoutSize: CGSize { clockLayoutSize(in: clockPlayfieldSize) }
  private var isWideLayout: Bool { ClockScreenLayout.usesSideSettingsPanel(screen: screenSize) }
  private var sidePanelWidth: CGFloat { ClockScreenLayout.sidePanelWidth(screen: screenSize) }
  private var clockPaused: Bool { showSettings || showFontPicker }

  #if os(iOS)
    private var isIOSSheetSettingsOpen: Bool { showSettings && !isWideLayout }
  #endif
  private var oledShiftActive: Bool {
    scenePhase == .active && !showSettings && !showFontPicker
  }

  private var oledShiftEnabledForClock: Bool {
    oledPixelShiftEnabled && !AppUITestConfig.isEnabled
  }

  var body: some View {
    panelClampLayer
  }

  private var panelClampLayer: some View {
    styleChangeLayer
      .onChangeCompat(of: screenSize) { _, _ in
        clampFontSizeToScreen()
        oledPixelShift.setScreenSize(screenSize)
      }
      .onChangeCompat(of: showSettings) { _, isOpen in
        #if os(iOS)
          if isOpen { return }
        #endif
        clampFontSizeToScreen()
      }
      .onChangeCompat(of: showFontPicker) { _, _ in clampFontSizeToScreen() }
  }

  private var styleChangeLayer: some View {
    configChangeLayer
      .onChangeCompat(of: clockDisplayStyleRaw) { _, _ in reactStyleChange() }
  }

  private var configChangeLayer: some View {
    sceneLifecycleLayer
      .onChangeCompat(of: fontSize) { _, _ in reactConfigChange() }
      .onChangeCompat(of: padZero) { _, _ in reactConfigChange() }
      .onChangeCompat(of: is24Hour) { _, _ in reactConfigChange() }
      .onChangeCompat(of: showAMPM) { _, _ in reactConfigChange() }
      .onChangeCompat(of: ampmSide) { _, _ in reactConfigChange() }
      .onChangeCompat(of: selectedTimeZone) { _, _ in reactConfigChange() }
      .onChangeCompat(of: showTimeZoneText) { _, _ in reactConfigChange() }
      .onChangeCompat(of: selectedFontName) { _, _ in reactConfigChange() }
      .onChangeCompat(of: timeDisplayPrecisionRaw) { _, _ in reactConfigChange() }
      .onChangeCompat(of: flipClockFormatRaw) { _, _ in reactConfigChange() }
      .onChangeCompat(of: flipCompactDetachedSeconds) { _, _ in reactConfigChange() }
      .onChangeCompat(of: avoidTopSafeAreaOnNotch) { _, _ in clampFontSizeToScreen() }
      .onChangeCompat(of: notchTopInsetTighten) { _, _ in clampFontSizeToScreen() }
  }

  private var sceneLifecycleLayer: some View {
    coreStack
      .onAppear(perform: handleAppear)
      .onChangeCompat(of: scenePhase) { _, phase in
        timeScheduler.setActive(phase == .active)
      }
      .onChangeCompat(of: keepDisplayAwake) { _, enabled in
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
      .onReceive(NotificationCenter.default.publisher(for: DVDCollisionDebug.collisionNotification)) { _ in
        guard DVDCollisionDebug.isEnabled, clockDisplayStyle == .classic else { return }
        let pause = DVDCollisionDebug.pauseDuration
        guard pause > 0 else { return }
        dvdCollisionDebugHit = true
        Task { @MainActor in
          try? await Task.sleep(nanoseconds: UInt64(pause * 1_000_000_000))
          dvdCollisionDebugHit = false
        }
      }
  }

  private var coreStack: some View {
    ZStack(alignment: .topLeading) {
      backgroundLayer
      clockLayer
      #if os(iOS)
        iosLongPressCaptureLayer
      #endif
      overlayStack
      settingsShortcutButton
    }
  }

  #if os(iOS)
    /// 仅接管长按，不参与布局；设置打开时关闭命中避免挡面板
    private var iosLongPressCaptureLayer: some View {
      Color.clear
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .allowsHitTesting(!showSettings && !showFontPicker)
        .onLongPressGesture(minimumDuration: 0.35, maximumDistance: 48) {
          toggleSettings()
        }
    }
  #endif

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
    clockScene(isPaused: clockPaused)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .padding(.top, clockTopInset)
      .clockLayoutBleedIfAvailable()
      .accessibilityIdentifier(TimeAccessibilityID.clockScene)
      .accessibilityElement(children: .contain)
      .oledPixelShift(
        engine: oledPixelShift,
        isEnabled: oledShiftEnabledForClock,
        isActive: oledShiftActive,
        screenSize: clockPlayfieldSize
      )
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

  private var effectiveBackgroundHex: String {
    if DVDCollisionDebug.isEnabled, dvdCollisionDebugHit, clockDisplayStyle == .classic {
      return DVDCollisionDebug.hitBackgroundHex
    }
    return backgroundColorHex
  }

  private var backgroundLayer: some View {
    Color(hex: effectiveBackgroundHex)
      .ignoresSafeArea()
      .contentShape(Rectangle())
      #if os(macOS)
        .contentShape(Rectangle())
        .onTapGesture {
          withAnimation {
            showSettings = false
            showFontPicker = false
          }
        }
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
  private func clockScene(isPaused: Bool) -> some View {
    switch clockDisplayStyle {
    case .classic:
      let style = classicClockStyle(screenSize: layoutSize)
      MotionClockScene(
        scheduler: timeScheduler,
        style: style,
        precision: timeDisplayPrecision,
        timeZoneTopGap: -style.timeZoneSize * 0.12,
        showTimeZoneText: showTimeZoneText,
        playfieldSize: clockPlayfieldSize,
        moveSpeed: moveSpeed,
        isActive: scenePhase == .active,
        isPaused: isPaused,
        backgroundColorHex: backgroundColorHex,
        fontColorHex: fontColorHex
      )
    case .flip:
      FlipClockScene(
        scheduler: timeScheduler,
        config: clockConfig.applyingDisplayStyle(.flip),
        backgroundColorHex: backgroundColorHex,
        flipCardColorHex: flipCardColorHex,
        fontColorHex: fontColorHex,
        isActive: scenePhase == .active && !isPaused
      )
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

  private var settingsDismissBackdrop: some View {
    Color.clear
      .contentShape(Rectangle())
      .ignoresSafeArea()
      .accessibilityIdentifier(TimeAccessibilityID.settingsBackdrop)
      .onTapGesture {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
          showSettings = false
        }
      }
  }

  private func settingsTransition(isWide: Bool) -> AnyTransition {
    if isWide {
      return .move(edge: .trailing).combined(with: .opacity)
    }
    return .move(edge: .bottom).combined(with: .opacity)
  }

  @ViewBuilder
  private func settingsOverlay(size: CGSize, isWide: Bool) -> some View {
    ZStack(alignment: isWide ? .trailing : .bottom) {
      // iOS 底部 sheet：遮罩不响应点击，避免长按抬手被当成「点空白关闭」
      #if os(iOS)
        if isWide {
          settingsDismissBackdrop
        }
      #else
        settingsDismissBackdrop
      #endif

      settingsPanel(in: size, isWide: isWide)
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
  private func settingsPanel(in size: CGSize, isWide: Bool) -> some View {
    let panel = SettingsPanelView(
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
      notchTopInsetTighten: $notchTopInsetTighten,
      layout: isWide ? .sidePanel : .bottomSheet,
      panelOffset: $settingsPanelOffset,
      settingsSheetWidth: $settingsSheetWidth,
        onSpeedChange: {}
    )
    let sheetHeight: CGFloat = {
      #if os(iOS)
        if !isWide { return min(size.height * 0.78, 560) }
      #endif
      return min(size.height * 0.88, 720)
    }()

    if isWide {
      panel
        .frame(width: min(400, size.width * 0.38))
        .padding(EdgeInsets(top: 20, leading: 0, bottom: 20, trailing: 20))
    } else {
      #if os(iOS)
        let sheetW = SettingsPanelMetrics.resolvedIOSSheetWidth(
          stored: settingsSheetWidth,
          screen: size
        )
        HStack(alignment: .bottom, spacing: 0) {
          Spacer(minLength: 0)
          panel
            .frame(width: sheetW, height: sheetHeight)
          Spacer(minLength: 0)
        }
        .padding(.bottom, 12)
      #else
        panel
          .frame(height: sheetHeight)
          .frame(maxWidth: .infinity)
          .padding(EdgeInsets(top: 0, leading: 12, bottom: 12, trailing: 12))
      #endif
    }
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
    timeScheduler.setFormat(clockConfig.schedulerFormatOptions(for: clockDisplayStyle))
    timeScheduler.setActive(scenePhase == .active)
    DisplayKeepAwake.setEnabled(keepDisplayAwake)
    if AppUITestConfig.openSettingsOnLaunch {
      showSettings = true
    }
    enterLaunchFullscreenIfNeeded()
    if clockDisplayStyle == .flip, !flipLaunchPresentationApplied {
      flipLaunchPresentationApplied = true
      applyFlipPresentation()
    } else {
      clampFontSizeToScreen()
    }
  }

  /// 启动即全屏（DVD / 翻页均适用；UI 测试跳过）
  private func enterLaunchFullscreenIfNeeded() {
    #if os(macOS)
      guard !AppUITestConfig.skipFlipLaunchFullscreen else { return }
      DispatchQueue.main.async {
        WindowFullscreen.enterIfNeeded()
      }
    #endif
  }

  private func reactConfigChange() {
    timeScheduler.setFormat(clockConfig.schedulerFormatOptions(for: clockDisplayStyle))
    #if os(iOS)
      guard !isIOSSheetSettingsOpen else { return }
    #endif
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
      clockDisplayStyle == .flip ? clockPlayfieldSize : clockLayoutSize(in: clockPlayfieldSize)
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
    if showSettings, ClockScreenLayout.usesSideSettingsPanel(screen: screen) {
      width -= ClockScreenLayout.settingsPanelWidth(screen: screen) + 48
    } else if showSettings {
      width *= 0.92
    }
    if showFontPicker {
      width -= ClockScreenLayout.sidePanelWidth(screen: screen) + 40
    }
    width = max(width, screen.width * 0.42)
    return CGSize(width: width, height: screen.height)
  }

  private func applyFlipPresentation() {
    showSettings = false
    showFontPicker = false
    ClockFontSizeLimits.applyFlipMaximumFontSize(
      &fontSize,
      screen: clockPlayfieldSize,
      config: clockConfig
    )
    enterLaunchFullscreenIfNeeded()
  }
}

#if os(macOS)
  import AppKit
#endif
