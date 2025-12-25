import SwiftUI

struct SettingsPanelView: View {
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
  @Binding var permanentOffset: CGSize
  @Binding var showDebugInfo: Bool
  @Binding var selectedFontName: String

  @GestureState private var interimOffset: CGSize = .zero
  var onSpeedChange: () -> Void

  var body: some View {
    // 使用 GeometryReader 动态感知容器大小（适配横竖屏）
    GeometryReader { geo in
      VStack(spacing: 0) {
        // 拖动手柄
        dragHandle

        ScrollView {
          VStack(alignment: .leading, spacing: 20) {
            Text("个性化设置")
              .font(.headline)
              .frame(maxWidth: .infinity)

            // 速度设置
            settingSlider(
              title: "速度",
              value: $moveSpeed,
              range: 0...1,
              label: "\(Int(moveSpeed*100))%"
            ) { onSpeedChange() }

            // 字号设置
            settingSlider(
              title: "字号",
              value: $fontSize,
              range: 30...350,
              label: "\(Int(fontSize))"
            )

            Divider().background(Color.white.opacity(0.1))

            // 时间制度
            VStack(alignment: .leading, spacing: 8) {
              Text("时间制度").font(.caption).foregroundColor(.gray)
              Picker("制度", selection: $is24Hour) {
                Text("12H").tag(false)
                Text("24H").tag(true)
              }
              .pickerStyle(.segmented)
              Toggle("前置补零", isOn: $padZero)
            }

            // AM/PM 功能区 (仅 12H 显示)
            if !is24Hour {
              VStack(alignment: .leading, spacing: 12) {
                Toggle("显示 AM/PM 标签", isOn: $showAMPM)
                if showAMPM {
                  Group {
                    Text("显示位置").font(.caption).foregroundColor(.gray)
                    Picker("位置", selection: $ampmSide) {
                      Text("前").tag("Leading")
                      Text("后").tag("Trailing")
                    }
                    .pickerStyle(.segmented)

                    Text("字体比例").font(.caption).foregroundColor(.gray)
                    Picker("比例", selection: $ampmScale) {
                      Text("1/4").tag(0.25)
                      Text("1/2").tag(0.5)
                      Text("等大").tag(1.0)
                    }
                    .pickerStyle(.segmented)
                  }
                  .transition(.opacity)
                }
              }
              .padding(10)
              .background(Color.white.opacity(0.05))
              .cornerRadius(12)
            }

            Divider().background(Color.white.opacity(0.1))

            Toggle("显示时区文案", isOn: $showTimeZoneText)
            Toggle("开发者 Debug 模式", isOn: $showDebugInfo)

            // 修改字体样式按钮
            Button(action: {
              withAnimation(.spring()) {
                showSettings = false
                showFontPicker = true
              }
            }) {
              HStack {
                Text("修改字体样式")
                Spacer()
                Text(selectedFontName)
                  .font(.caption2)
                  .lineLimit(1)
                  .foregroundColor(.blue)
                Image(systemName: "chevron.right")
              }
              .padding()
              .background(Color.white.opacity(0.1))
              .cornerRadius(12)
            }

            // 完成按钮
            Button("完成") {
              withAnimation { showSettings = false }
            }
            .bold()
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
          }
          .padding(20)
        }
      }
      .foregroundColor(.white)
      // 核心修复：根据屏幕高度动态调整面板最大高度，确保可以滑动
      .frame(width: 320)
      .frame(maxHeight: geo.size.height * 0.9)
      .background(
        ZStack {
          RoundedRectangle(cornerRadius: 30, style: .continuous).fill(.ultraThinMaterial)
          RoundedRectangle(cornerRadius: 30, style: .continuous).fill(
            Color(white: 0.15).opacity(0.8))
        }
      )
      // 居中定位
      .position(x: geo.size.width / 2, y: geo.size.height / 2)
      // 应用拖拽位移
      .offset(
        x: permanentOffset.width + interimOffset.width,
        y: permanentOffset.height + interimOffset.height
      )
    }
  }

  private var dragHandle: some View {
    Capsule()
      .fill(Color.gray.opacity(0.5))
      .frame(width: 40, height: 5)
      .padding(.vertical, 12)
      .frame(maxWidth: .infinity)
      .background(Color.clear)
      .contentShape(Rectangle())
      .gesture(
        DragGesture()
          .updating($interimOffset) { v, s, _ in
            s = v.translation
          }
          .onEnded { v in
            permanentOffset.width += v.translation.width
            permanentOffset.height += v.translation.height
          }
      )
  }

  @ViewBuilder
  private func settingSlider(
    title: String,
    value: Binding<Double>,
    range: ClosedRange<Double>,
    label: String,
    onEdit: (() -> Void)? = nil
  ) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack {
        Text(title)
        Spacer()
        Text(label).foregroundColor(.blue)
      }
      .font(.caption)
      Slider(value: value, in: range)
        .onChange(of: value.wrappedValue) { _, _ in
          onEdit?()
        }
    }
  }
}
