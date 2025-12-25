import Combine
import SwiftUI

struct ContentView: View {
  // --- 1. 持久化设置 ---
  @AppStorage("moveSpeed") private var moveSpeed: Double = 0.5
  @AppStorage("fontSize") private var fontSize: Double = 80
  @AppStorage("is24Hour") private var is24Hour: Bool = false
  @AppStorage("showAMPM") private var showAMPM: Bool = true
  @AppStorage("ampmScale") private var ampmScale: Double = 0.25
  @AppStorage("ampmSide") private var ampmSide: String = "Leading"

  // --- 2. 内部状态 ---
  @State private var showSettings = false
  @State private var position: CGPoint? = nil
  @State private var velocity: CGVector = .zero
  @State private var direction: CGVector = CGVector(dx: 1, dy: 1)
  @State private var clockColor: Color = .white
  @State private var currentTime = Date()
  @State private var totalSize: CGSize = .zero

  @State private var settingsOffset: CGSize = .zero
  @State private var dragOffset: CGSize = .zero

  let timer = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()

  var body: some View {
    GeometryReader { screenGeo in
      let centerPoint = CGPoint(x: screenGeo.size.width / 2, y: screenGeo.size.height / 2)

      ZStack {
        Color.black.ignoresSafeArea()
          .contentShape(Rectangle())
          .onTapGesture {
            if showSettings { withAnimation(.spring()) { showSettings = false } }
          }
          .contextMenu {
            Button("设置") { triggerSettings() }
            Button("切换 12/24h") { is24Hour.toggle() }
          }
          .onLongPressGesture(minimumDuration: 0.5) {
            triggerSettings()
          }

        // --- 时钟主体 ---
        HStack(alignment: .lastTextBaseline, spacing: fontSize * 0.05) {
          // 【修复】增加 !is24Hour 判断，确保 24 小时模式不显示 AM/PM
          if !is24Hour && showAMPM && ampmSide == "Leading" { ampmTextComponent }

          Text(mainTimeStrings(currentTime))
            .font(.system(size: fontSize, weight: .bold, design: .monospaced))
            .id(is24Hour ? "24" : "12")  // 强制刷新文本视图

          // 【修复】增加 !is24Hour 判断
          if !is24Hour && showAMPM && ampmSide == "Trailing" { ampmTextComponent }
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
      .background(
        Button("") { triggerSettings() }
          .keyboardShortcut(",", modifiers: .command)
          .opacity(0)
      )
      .onReceive(timer) { input in
        self.currentTime = input
        if isSpaceEnough(for: screenGeo.size) {
          updatePosition(in: screenGeo.size)
        }
      }
      .onAppear { updateVelocity() }
    }
  }

  private var ampmTextComponent: some View {
    Text(getAMPMString(currentTime))
      .font(.system(size: fontSize * ampmScale, weight: .bold, design: .monospaced))
  }

  private var settingsPanelView: some View {
    VStack(spacing: 0) {
      ZStack {
        Rectangle().fill(Color.white.opacity(0.0001))
        Capsule().fill(Color.gray.opacity(0.4)).frame(width: 40, height: 5)
      }
      .frame(height: 40)
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in dragOffset = value.translation }
          .onEnded { value in
            settingsOffset.width += value.translation.width
            settingsOffset.height += value.translation.height
            dragOffset = .zero
          }
      )

      ScrollView {
        VStack(spacing: 20) {
          Text("个性化设置").font(.headline).foregroundColor(.white)
          VStack(spacing: 15) {
            Toggle("24小时制", isOn: $is24Hour)
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
          }
          .foregroundColor(.white).padding(.horizontal)
          Divider().background(Color.gray.opacity(0.3))
          VStack(alignment: .leading, spacing: 12) {
            Text("移动速度: \(Int(moveSpeed * 100))%").font(.caption).foregroundColor(.gray)
            Slider(value: $moveSpeed, in: 0...1).onChange(of: moveSpeed) { _, _ in updateVelocity()
            }
            Text("主字号: \(Int(fontSize))").font(.caption).foregroundColor(.gray)
            Slider(value: $fontSize, in: 30...350)
          }
          .padding(.horizontal)
          Button("完成") { withAnimation(.spring()) { showSettings = false } }
            .buttonStyle(.borderedProminent).padding(.top, 10)
        }
        .padding(.bottom, 25)
      }
    }
    .frame(width: 300, height: 460)
    .background(
      RoundedRectangle(cornerRadius: 24)
        .fill(Color(white: 0.12).opacity(0.95))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    )
    .clipShape(RoundedRectangle(cornerRadius: 24))
    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.gray.opacity(0.2), lineWidth: 1))
    .onTapGesture {}
  }

  private func isSpaceEnough(for screenSize: CGSize) -> Bool {
    return screenSize.width > (totalSize.width + 20) && screenSize.height > (totalSize.height + 20)
  }

  private func triggerSettings() {
    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
      showSettings.toggle()
    }
  }

  private func updateVelocity() {
    let baseSpeed: CGFloat = 10.0
    velocity = CGVector(
      dx: direction.dx * baseSpeed * CGFloat(moveSpeed),
      dy: direction.dy * baseSpeed * CGFloat(moveSpeed))
  }

  private func updatePosition(in screenSize: CGSize) {
    let margin: CGFloat = 5
    let w = totalSize.width + margin
    let h = totalSize.height + margin
    let currentPos = position ?? CGPoint(x: screenSize.width / 2, y: screenSize.height / 2)
    var newX = currentPos.x + velocity.dx
    var newY = currentPos.y + velocity.dy

    if newX <= w / 2 {
      direction.dx = 1
      updateVelocity()
      clockColor = randomColor()
      newX = w / 2 + 1
    } else if newX >= screenSize.width - w / 2 {
      direction.dx = -1
      updateVelocity()
      clockColor = randomColor()
      newX = screenSize.width - w / 2 - 1
    }
    if newY <= h / 2 {
      direction.dy = 1
      updateVelocity()
      clockColor = randomColor()
      newY = h / 2 + 1
    } else if newY >= screenSize.height - h / 2 {
      direction.dy = -1
      updateVelocity()
      clockColor = randomColor()
      newY = screenSize.height - h / 2 - 1
    }
    position = CGPoint(x: newX, y: newY)
  }

  private func randomColor() -> Color {
    let colors: [Color] = [.red, .green, .blue, .orange, .purple, .cyan, .pink, .yellow, .white]
    return colors.randomElement()?.opacity(0.85) ?? .white
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

  private func mainTimeStrings(_ date: Date) -> String {
    let f = DateFormatter()
    // 【关键修复】使用 Locale 锁定格式，不受系统 12/24h 设置影响
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = is24Hour ? "HH:mm" : "hh:mm"
    return f.string(from: date)
  }

  private func getAMPMString(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "a"
    return f.string(from: date)
  }
}
