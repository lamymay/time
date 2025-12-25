import Combine
import SwiftUI

struct ContentView: View {
  // --- 持久化设置 ---
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

  // --- 状态管理 ---
  @StateObject private var vm = ClockViewModel()
  @State private var showSettings = false
  @State private var showFontPicker = false
  @State private var permanentOffset: CGSize = .zero
  @State private var allFonts: [String] = []

  // 定时器：30FPS 刷新
  let timer = Timer.publish(every: 0.033, on: .main, in: .common).autoconnect()

  // 逻辑判定：24小时模式下隐藏 AMPM
  private var effectiveShowAMPM: Bool { is24Hour ? false : showAMPM }

  var body: some View {
    GeometryReader { screenGeo in
      let pickerWidth: CGFloat = 300

      ZStack(alignment: .topLeading) {
        // 背景交互层
        Color.black.ignoresSafeArea()
          .contentShape(Rectangle())
          .onTapGesture {
            withAnimation {
              showSettings = false
              showFontPicker = false
            }
          }
          .onLongPressGesture(minimumDuration: 0.5) {
            toggleSettings()
          }
          #if os(macOS)
            // 仅在 macOS 保留 ContextMenu，iOS 使用长按手势避免快照黑屏
            .contextMenu {
              Button("个性化设置") { toggleSettings() }
              Divider()
              Button("退出程序") { NSApplication.shared.terminate(nil) }
            }
          #endif

        // --- 1. 时钟主体 ---
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
            // 使用 id 确保字体切换时视图能够正确响应
            .id("\(selectedFontName)-\(is24Hour)-\(padZero)")

            if ampmSide == "Trailing" && effectiveShowAMPM && !ampm.isEmpty {
              Text(ampm).font(getCustomFont(size: fontSize * ampmScale))
            }
          }
          // 性能优化：将复杂的文本渲染离屏缓存到 GPU，减少切换字体时的闪烁和卡顿
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

        // --- 2. Debug 面板 ---
        if showDebugInfo {
          debugOverlayView
        }

        // --- 3. 设置面板 ---
        if showSettings && !showFontPicker {
          SettingsPanelView(
            moveSpeed: $moveSpeed, fontSize: $fontSize, padZero: $padZero, is24Hour: $is24Hour,
            showAMPM: $showAMPM, ampmScale: $ampmScale, ampmSide: $ampmSide,
            showTimeZoneText: $showTimeZoneText, selectedTimeZone: $selectedTimeZone,
            showSettings: $showSettings, showFontPicker: $showFontPicker,
            permanentOffset: $permanentOffset, showDebugInfo: $showDebugInfo,
            onSpeedChange: { vm.updateVelocity(speed: moveSpeed) }
          )
          .zIndex(100)
          .transition(.scale.combined(with: .opacity))
        }

        // --- 4. 字体选择侧边栏 ---
        if showFontPicker {
          HStack(spacing: 0) {
            Spacer()
            SideFontPickerView(
              isPresented: $showFontPicker,
              selectedFontName: $selectedFontName,
              allFonts: allFonts
            )
            .frame(width: pickerWidth)
            .transition(.move(edge: .trailing))
          }
          .zIndex(200)
        }

        // 快捷键支持 (macOS)
        Button(action: toggleSettings) { Color.clear.frame(width: 1, height: 1) }
          .keyboardShortcut(",", modifiers: .command)
          .buttonStyle(.plain)
      }
      .onReceive(timer) { input in
        vm.currentTime = input
        vm.updatePosition(
          in: screenGeo.size,
          isPickerOpen: showFontPicker,
          pickerWidth: pickerWidth,
          speed: moveSpeed
        )
      }
      .onAppear { setupApp() }
    }
  }

  // --- 辅助视图与逻辑 ---

  private var debugOverlayView: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("[SYSTEM] \(TimeProvider.getFullSystemTime(from: vm.currentTime))")
      Text(
        "[LOGIC] is24H:\(String(is24Hour)) | RawAMPM:\(String(showAMPM)) | Effective:\(effectiveShowAMPM ? "ON" : "OFF")"
      )
      Text(
        "[LAYOUT] Size:\(String(describing: vm.totalSize)) | Pos:\(String(describing: vm.position ?? .zero))"
      )
      Text(
        "[OUTPUT] \"\(TimeProvider.getTimeString(from: vm.currentTime, is24Hour: is24Hour, padZero: padZero, timeZoneIdentifier: selectedTimeZone))\""
      )
    }
    .font(.system(size: 10, design: .monospaced))
    .foregroundColor(.green.opacity(0.9))
    .padding(10)
    .background(Color.black.opacity(0.4))
    .padding(10)
    .zIndex(50)
  }

  private func toggleSettings() {
    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
      showSettings.toggle()
      if showSettings { showFontPicker = false }
    }
  }

  private func setupApp() {
    // 1. 初始化预设字体
    self.allFonts = ["System Default", "System Monospaced", "System Rounded", "System Serif"]

    // 2. 异步加载全量系统字体，防止阻塞 UI
    DispatchQueue.global(qos: .userInitiated).async {
      var loadedFonts: [String] = []

      #if os(iOS)
        loadedFonts = UIFont.familyNames.sorted()
      #elseif os(macOS)
        loadedFonts = NSFontManager.shared.availableFontFamilies.sorted()
      #endif

      DispatchQueue.main.async {
        let combined = (self.allFonts + loadedFonts)
        // 使用 NSOrderedSet 去重并保持顺序
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
