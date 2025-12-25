import Combine
import SwiftUI

// --- 性能优化：静态缓存 Formatter，避免高频创建销毁导致的内存抖动 ---
struct AppTimeCache {
  static let formatter = DateFormatter()
}

struct ContentView: View {
  // --- 1. 持久化设置 ---
  @AppStorage("moveSpeed") private var moveSpeed: Double = 0.5
  @AppStorage("fontSize") private var fontSize: Double = 80
  @AppStorage("padZero") private var padZero: Bool = true
  @AppStorage("is24Hour") private var is24Hour: Bool = false
  @AppStorage("showAMPM") private var showAMPM: Bool = true
  @AppStorage("ampmScale") private var ampmScale: Double = 0.25
  @AppStorage("ampmSide") private var ampmSide: String = "Leading"
  @AppStorage("selectedTimeZone") private var selectedTimeZone: String = TimeZone.current.identifier
  @AppStorage("showTimeZoneText") private var showTimeZoneText: Bool = true
  @AppStorage("colorBlacklist") private var colorBlacklist: String = ""

  // --- 2. 内部状态 ---
  @State private var showSettings = false
  @State private var position: CGPoint? = nil
  @State private var velocity: CGVector = .zero
  @State private var direction: CGVector = CGVector(dx: 1, dy: 1)

  // 初始颜色设为绿色
  @State private var clockColor: Color = .green
  @State private var currentHue: Double = 0.33

  @State private var currentTime = Date()
  @State private var totalSize: CGSize = .zero
  @State private var settingsOffset: CGSize = .zero
  @State private var dragOffset: CGSize = .zero

  // 优化：30 FPS (0.033s) 兼顾丝滑感与极致省电
  let timer = Timer.publish(every: 0.033, on: .main, in: .common).autoconnect()
  let allTimeZones = TimeZone.knownTimeZoneIdentifiers.sorted()

  var body: some View {
    GeometryReader { screenGeo in
      let centerPoint = CGPoint(x: screenGeo.size.width / 2, y: screenGeo.size.height / 2)

      ZStack {
        // 背景层：处理点击关闭和长按开启
        Color.black.ignoresSafeArea()
          .contentShape(Rectangle())
          .onTapGesture {
            if showSettings { withAnimation(.spring()) { showSettings = false } }
          }
          .onLongPressGesture(minimumDuration: 0.5) {
            triggerSettings()
          }
          // 适配 macOS 的右键点击
          .onTapGesture(count: 1, perform: { /* 占位防止冲突 */  })
          // 使用编译判断：仅在 macOS 下编译此段代码
          #if os(macOS)
            .simultaneousGesture(
              TapGesture().modifiers(.control).onEnded { _ in
                triggerSettings()
              }
            )
          #endif

        // 快捷键支持 (Command + ,)
        Button("") { triggerSettings() }
          .keyboardShortcut(",", modifiers: .command)
          .opacity(0)

        // --- 时钟主体 ---
        VStack(alignment: .center, spacing: 5) {
          HStack(alignment: .lastTextBaseline, spacing: fontSize * 0.05) {
            if !is24Hour && showAMPM && ampmSide == "Leading" { ampmTextComponent }

            Text(mainTimeStrings(currentTime))
              .font(.system(size: fontSize, weight: .bold, design: .monospaced))
              .id("\(is24Hour)-\(padZero)-\(selectedTimeZone)")

            if !is24Hour && showAMPM && ampmSide == "Trailing" { ampmTextComponent }
          }

          if showTimeZoneText {
            Text(timeZoneDisplayString)
              .font(.system(size: fontSize * 0.2, weight: .medium, design: .monospaced))
              .opacity(0.8)
          }
        }
        .foregroundColor(clockColor)
        .background(
          GeometryReader { geo in
            Color.clear
              .onAppear { self.totalSize = geo.size }
              .onChange(of: geo.size) { _, newSize in self.totalSize = newSize }
          }
        )
        .position(isSpaceEnough(for: screenGeo.size) ? (position ?? centerPoint) : centerPoint)
        // 时钟主体也绑定长按，确保点击时钟也能打开设置
        .onLongPressGesture(minimumDuration: 0.5) {
          triggerSettings()
        }

        // 设置面板层
        if showSettings {
          settingsPanelView
            .offset(
              x: settingsOffset.width + dragOffset.width,
              y: settingsOffset.height + dragOffset.height
            )
            .transition(
              .asymmetric(
                insertion: .scale(scale: 0.95).combined(with: .opacity), removal: .opacity)
            )
            .zIndex(10)
        }
      }
      .onReceive(timer) { input in
        self.currentTime = input
        if isSpaceEnough(for: screenGeo.size) { updatePosition(in: screenGeo.size) }
      }
      .onAppear {
        updateVelocity()
        if TimeZone(identifier: selectedTimeZone) == nil {
          selectedTimeZone = TimeZone.current.identifier
        }
      }
    }
  }

  // --- UI 组件 ---

  private var ampmTextComponent: some View {
    Text(getAMPMString(currentTime))
      .font(.system(size: fontSize * ampmScale, weight: .bold, design: .monospaced))
  }

  private var settingsPanelView: some View {
    VStack(spacing: 0) {
      dragHandle.frame(height: 35)
      ScrollView {
        VStack(spacing: 20) {
          Text("个性化设置").font(.headline).foregroundColor(.white)

          VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
              Text("移动速度: \(Int(moveSpeed * 100))%").font(.caption).foregroundColor(.gray)
              Slider(value: $moveSpeed, in: 0...1).onChange(of: moveSpeed) { _, _ in
                updateVelocity()
              }
            }
            VStack(alignment: .leading, spacing: 6) {
              Text("主字号: \(Int(fontSize))").font(.caption).foregroundColor(.gray)
              Slider(value: $fontSize, in: 30...350)
            }
          }.padding(.horizontal)

          Divider().background(Color.gray.opacity(0.3))

          VStack(alignment: .leading, spacing: 15) {
            Toggle("时间前置补零 (如 09:41)", isOn: $padZero)
            Toggle("24 小时制", isOn: $is24Hour)
            if !is24Hour {
              Toggle("显示 AM/PM", isOn: $showAMPM)
              if showAMPM {
                pickerRow(title: "位置", selection: $ampmSide) {
                  Text("前").tag("Leading")
                  Text("后").tag("Trailing")
                }
                pickerRow(title: "比例", selection: $ampmScale) {
                  Text("1/4").tag(0.25)
                  Text("1/2").tag(0.5)
                  Text("等大").tag(1.0)
                }
              }
            }
            Toggle("显示时区文字", isOn: $showTimeZoneText)
          }.foregroundColor(.white).padding(.horizontal)

          Divider().background(Color.gray.opacity(0.3))

          VStack(alignment: .leading, spacing: 10) {
            Text("颜色管理").font(.caption2).foregroundColor(.gray)
            HStack {
              Button("屏蔽当前颜色") { banCurrentColor() }
                .buttonStyle(.bordered)
              Button("重置颜色黑名单") { colorBlacklist = "" }
                .buttonStyle(.bordered)
            }
          }.padding(.horizontal)

          VStack(alignment: .leading, spacing: 8) {
            Text("时区配置").font(.caption2).foregroundColor(.gray)
            Picker("选择时区", selection: $selectedTimeZone) {
              ForEach(allTimeZones, id: \.self) { tz in
                Text(tz.replacingOccurrences(of: "_", with: " ")).tag(tz)
              }
            }.pickerStyle(.menu).labelsHidden()
          }.padding(.horizontal)

          Button("完成") { withAnimation(.spring()) { showSettings = false } }
            .buttonStyle(.borderedProminent).padding(.top, 5)
        }.padding(.bottom, 25)
      }
    }
    .frame(width: 300, height: 580)
    .background(
      RoundedRectangle(cornerRadius: 24).fill(Color(white: 0.12).opacity(0.95)).background(
        .ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    )
    .clipShape(RoundedRectangle(cornerRadius: 24))
    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.gray.opacity(0.2), lineWidth: 1))
    .onTapGesture {}  // 阻止内部点击穿透
  }

  // --- 逻辑处理 ---

  private func triggerSettings() {
    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
      showSettings = true
    }
  }

  private func banCurrentColor() {
    let hueStr = String(format: "%.1f", currentHue)
    var list = colorBlacklist.split(separator: ",").map(String.init)
    if !list.contains(hueStr) {
      list.append(hueStr)
      colorBlacklist = list.joined(separator: ",")
    }
    clockColor = generateRandomColor()
  }

  private func generateRandomColor() -> Color {
    let bannedHues = colorBlacklist.split(separator: ",").compactMap { Double($0) }
    var newHue: Double = 0
    var attempts = 0
    repeat {
      newHue = Double.random(in: 0...1)
      attempts += 1
      let isBanned = bannedHues.contains { abs($0 - newHue) < 0.05 }
      if !isBanned || attempts > 20 { break }
    } while true
    currentHue = newHue
    return Color(
      hue: newHue, saturation: Double.random(in: 0.7...0.9),
      brightness: Double.random(in: 0.7...0.9))
  }

  private func updatePosition(in screenSize: CGSize) {
    let margin: CGFloat = 5
    let w = totalSize.width + margin
    let h = totalSize.height + margin
    let currentPos = position ?? CGPoint(x: screenSize.width / 2, y: screenSize.height / 2)
    var newX = currentPos.x + velocity.dx
    var newY = currentPos.y + velocity.dy
    var didHit = false

    if newX <= w / 2 {
      direction.dx = 1
      newX = w / 2 + 1
      didHit = true
    } else if newX >= screenSize.width - w / 2 {
      direction.dx = -1
      newX = screenSize.width - w / 2 - 1
      didHit = true
    }

    if newY <= h / 2 {
      direction.dy = 1
      newY = h / 2 + 1
      didHit = true
    } else if newY >= screenSize.height - h / 2 {
      direction.dy = -1
      newY = screenSize.height - h / 2 - 1
      didHit = true
    }

    if didHit {
      updateVelocity()
      clockColor = generateRandomColor()
    }
    position = CGPoint(x: newX, y: newY)
  }

  private var timeZoneDisplayString: String {
    let city =
      selectedTimeZone.split(separator: "/").last?.replacingOccurrences(of: "_", with: " ")
      ?? selectedTimeZone
    let tz = TimeZone(identifier: selectedTimeZone)
    let abbreviation = tz?.abbreviation(for: currentTime) ?? ""
    return "\(city) (\(abbreviation))"
  }

  private func updateVelocity() {
    let baseSpeed: CGFloat = 10.0
    velocity = CGVector(
      dx: direction.dx * baseSpeed * CGFloat(moveSpeed),
      dy: direction.dy * baseSpeed * CGFloat(moveSpeed))
  }

  private func mainTimeStrings(_ date: Date) -> String {
    let f = AppTimeCache.formatter
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: selectedTimeZone) ?? .current
    f.dateFormat = is24Hour ? (padZero ? "HH:mm" : "H:mm") : (padZero ? "hh:mm" : "h:mm")
    let result = f.string(from: date)
    return (!padZero && result.count < 5) ? " " + result : result
  }

  private func getAMPMString(_ date: Date) -> String {
    let f = AppTimeCache.formatter
    f.timeZone = TimeZone(identifier: selectedTimeZone) ?? .current
    f.dateFormat = "a"
    return f.string(from: date)
  }

  private var dragHandle: some View {
    ZStack {
      Rectangle().fill(Color.white.opacity(0.0001))
      Capsule().fill(Color.gray.opacity(0.4)).frame(width: 40, height: 5)
    }
    .contentShape(Rectangle())
    .gesture(
      DragGesture(minimumDistance: 0).onChanged { value in dragOffset = value.translation }.onEnded
      { value in
        settingsOffset.width += value.translation.width
        settingsOffset.height += value.translation.height
        dragOffset = .zero
      })
  }

  @ViewBuilder
  private func pickerRow<T: Hashable, Content: View>(
    title: String, selection: Binding<T>, @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(title).font(.caption2).foregroundColor(.gray)
      Picker(title, selection: selection) { content() }.pickerStyle(.segmented)
    }
  }

  private func isSpaceEnough(for screenSize: CGSize) -> Bool {
    return screenSize.width > (totalSize.width + 20) && screenSize.height > (totalSize.height + 20)
  }
}
