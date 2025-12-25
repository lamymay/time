import Combine
import SwiftUI

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

  @StateObject private var vm = ClockViewModel()
  @State private var showSettings = false
  @State private var showFontPicker = false
  @State private var permanentOffset: CGSize = .zero
  @State private var allFonts: [String] = []

  let timer = Timer.publish(every: 0.033, on: .main, in: .common).autoconnect()
  private var effectiveShowAMPM: Bool { is24Hour ? false : showAMPM }

  var body: some View {
    GeometryReader { screenGeo in
      let uiSidePanelWidth: CGFloat = screenGeo.size.width > 600 ? 300 : screenGeo.size.width * 0.7

      ZStack(alignment: .topLeading) {
        Color.black.ignoresSafeArea()
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
              Button("个性化设置") { toggleSettings() }
              Divider()
              Button("退出程序") { NSApplication.shared.terminate(nil) }
            }
          #endif

        // 1. 时钟主体
        VStack(alignment: .center, spacing: 10) {
          HStack(alignment: .lastTextBaseline, spacing: fontSize * 0.06) {
            let ampm = TimeProvider.getAMPMString(
              from: vm.currentTime, is24Hour: is24Hour, timeZoneIdentifier: selectedTimeZone)
            if ampmSide == "Leading" && effectiveShowAMPM && !ampm.isEmpty {
              Text(ampm).font(getCustomFont(size: fontSize * ampmScale))
            }
            Text(
              TimeProvider.getTimeString(
                from: vm.currentTime, is24Hour: is24Hour, padZero: padZero,
                timeZoneIdentifier: selectedTimeZone)
            )
            .font(getCustomFont(size: fontSize))
            .id("\(selectedFontName)-\(is24Hour)-\(padZero)")
            if ampmSide == "Trailing" && effectiveShowAMPM && !ampm.isEmpty {
              Text(ampm).font(getCustomFont(size: fontSize * ampmScale))
            }
          }
          .drawingGroup()

          if showTimeZoneText {
            Text(TimeProvider.getTimeZoneString(for: selectedTimeZone, date: vm.currentTime))
              .font(getCustomFont(size: fontSize * 0.22))
          }
        }
        .foregroundColor(vm.clockColor)
        .background(
          GeometryReader { geo in
            Color.clear
              .onAppear { vm.totalSize = geo.size }
              .onChange(of: geo.size) { _, newSize in vm.totalSize = newSize }
          }
        )
        .position(vm.position ?? CGPoint(x: screenGeo.size.width / 2, y: screenGeo.size.height / 2))

        // 2. Debug 面板
        if showDebugInfo {
          debugOverlayView
        }

        // 3. 设置面板 (居中悬浮)
        if showSettings {
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
            permanentOffset: $permanentOffset,
            showDebugInfo: $showDebugInfo,
            selectedFontName: $selectedFontName,  // --- 确保传入这个绑定 ---
            onSpeedChange: { vm.updateVelocity(speed: moveSpeed) }
          )
          .zIndex(100)
          .transition(.scale.combined(with: .opacity))
        }

        // 4. 字体侧边栏 (右侧滑入)
        if showFontPicker {
          HStack(spacing: 0) {
            Spacer()
            SideFontPickerView(
              isPresented: $showFontPicker,
              selectedFontName: $selectedFontName,
              allFonts: allFonts
            )
            .frame(width: uiSidePanelWidth)
            .transition(.move(edge: .trailing))
          }
          .zIndex(200)  // 确保在最上层
        }

        Button(action: toggleSettings) { Color.clear.frame(width: 1, height: 1) }
          .keyboardShortcut(",", modifiers: .command)
          .buttonStyle(.plain)
      }
      .onReceive(timer) { input in
        vm.currentTime = input
        vm.updatePosition(in: screenGeo.size, isPickerOpen: false, pickerWidth: 0, speed: moveSpeed)
      }
      .onAppear { setupApp() }
    }
  }

  private var debugOverlayView: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("[SYSTEM] \(TimeProvider.getFullSystemTime(from: vm.currentTime))")
      Text("[LOGIC] is24H:\(String(is24Hour)) | Font: \(selectedFontName)")
    }
    .font(.system(size: 10, design: .monospaced))
    .foregroundColor(.green.opacity(0.9))
    .padding(10).background(Color.black.opacity(0.4)).padding(10).zIndex(50)
  }

  private func toggleSettings() {
    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
      showSettings.toggle()
      if showSettings { showFontPicker = false }
    }
  }

  private func setupApp() {
    self.allFonts = ["System Default", "System Monospaced", "System Rounded", "System Serif"]
    DispatchQueue.global(qos: .userInitiated).async {
      var loadedFonts: [String] = []
      #if os(iOS)
        loadedFonts = UIFont.familyNames.sorted()
      #elseif os(macOS)
        loadedFonts = NSFontManager.shared.availableFontFamilies.sorted()
      #endif
      DispatchQueue.main.async {
        let combined = (self.allFonts + loadedFonts)
        self.allFonts = Array(NSOrderedSet(array: combined)) as? [String] ?? combined
      }
    }
    vm.updateVelocity(speed: moveSpeed)
  }

  private func getCustomFont(size: CGFloat) -> Font {
    switch selectedFontName {
    case "System Default": return .system(size: size, weight: .bold)
    case "System Monospaced": return .system(size: size, weight: .bold, design: .monospaced)
    case "System Rounded": return .system(size: size, weight: .bold, design: .rounded)
    case "System Serif": return .system(size: size, weight: .bold, design: .serif)
    default: return .custom(selectedFontName, size: size).weight(.bold)
    }
  }
}
