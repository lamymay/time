import SwiftUI

enum SettingsPanelLayout {
  case sidePanel
  case bottomSheet
}

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
  @Binding var showDebugInfo: Bool
  @Binding var selectedFontName: String
  @Binding var backgroundColorHex: String
  @Binding var timeDisplayPrecisionRaw: String
  @Binding var clockDisplayStyleRaw: String
  @Binding var keepDisplayAwake: Bool

  let layout: SettingsPanelLayout
  @Binding var panelOffset: CGSize
  var onSpeedChange: () -> Void

  @GestureState private var dragOffset: CGSize = .zero

  private var precision: TimeDisplayPrecision {
    TimeDisplayPrecision.resolved(fromRaw: timeDisplayPrecisionRaw)
  }

  private var displayStyle: ClockDisplayStyle {
    ClockDisplayStyle(rawValue: clockDisplayStyleRaw) ?? .classic
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          appearanceSection
          if displayStyle == .classic {
            motionSection
          }
          timeFormatSection
          displaySection
          advancedSection
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .padding(.bottom, layout == .bottomSheet ? 8 : 16)
      }
      #if os(iOS)
        if layout == .bottomSheet {
          footerDoneButton
        }
      #endif
    }
    .foregroundStyle(.white)
    .background(panelBackground)
    .clipShape(RoundedRectangle(cornerRadius: SettingsTheme.panelCornerRadius, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: SettingsTheme.panelCornerRadius, style: .continuous)
        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
    )
    .shadow(color: .black.opacity(0.45), radius: 24, y: 8)
    .offset(
      x: panelOffset.width + dragOffset.width,
      y: panelOffset.height + dragOffset.height
    )
    #if os(macOS)
      .frame(minWidth: 360, idealWidth: 380)
    #endif
  }

  // MARK: - Header

  private var header: some View {
    VStack(spacing: 0) {
      dragHandle

      HStack(alignment: .center) {
        Text("设置")
          .font(.title2.weight(.semibold))
        Spacer()
        Button(action: closePanel) {
          Image(systemName: "xmark.circle.fill")
            .font(.title2)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        #if os(macOS)
          .keyboardShortcut(.escape, modifiers: [])
          .help("关闭设置")
        #endif
      }
      .padding(.horizontal, 18)
      .padding(.top, 4)
      .padding(.bottom, 12)

      Divider().overlay(SettingsTheme.separator)
    }
    .contentShape(Rectangle())
    .gesture(panelDragGesture)
  }

  private var dragHandle: some View {
    HStack {
      Spacer()
      Capsule()
        .fill(Color.white.opacity(0.28))
        .frame(width: 36, height: 5)
      Spacer()
    }
    .padding(.top, layout == .bottomSheet ? 10 : 12)
    .padding(.bottom, 6)
    .accessibilityLabel("拖动手柄")
  }

  private var panelDragGesture: some Gesture {
    DragGesture(minimumDistance: 4)
      .updating($dragOffset) { value, state, _ in
        state = value.translation
      }
      .onEnded { value in
        panelOffset.width += value.translation.width
        panelOffset.height += value.translation.height
      }
  }

  // MARK: - Sections

  private var appearanceSection: some View {
    SettingsSection(title: "外观", systemImage: "paintbrush") {
      labeledPickerRow(title: "时钟样式") {
        Picker("样式", selection: $clockDisplayStyleRaw) {
          ForEach(ClockDisplayStyle.allCases) { style in
            Text(style.label).tag(style.rawValue)
          }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
      }
      Text(displayStyle.subtitle)
        .font(.caption)
        .foregroundStyle(SettingsTheme.secondaryText)

      settingSlider(
        title: "字号",
        value: $fontSize,
        range: 30...350,
        label: "\(Int(fontSize))"
      )
      backgroundColorPicker
      if displayStyle == .classic {
        fontPickerRow
      }
    }
  }

  private var motionSection: some View {
    SettingsSection(title: "运动", systemImage: "arrow.up.left.and.arrow.down.right") {
      settingSlider(
        title: "移动速度",
        value: $moveSpeed,
        range: MoveSpeedLimits.min...MoveSpeedLimits.max,
        label: MoveSpeedLimits.displayLabel(for: moveSpeed)
      ) { onSpeedChange() }
      Text("设为「静止」可固定时钟位置，适合纯屏保展示。")
        .font(.caption)
        .foregroundStyle(SettingsTheme.secondaryText)
    }
  }

  private var timeFormatSection: some View {
    SettingsSection(title: "时间", systemImage: "clock") {
      labeledPickerRow(title: "时制") {
        Picker("时制", selection: $is24Hour) {
          Text("12 小时").tag(false)
          Text("24 小时").tag(true)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
      }

      SettingsToggleRow(title: "小时前置补零", isOn: $padZero)

      if !is24Hour {
        SettingsToggleRow(title: "显示 AM / PM", isOn: $showAMPM)
        if showAMPM {
          labeledPickerRow(title: "AM/PM 位置") {
            Picker("位置", selection: $ampmSide) {
              Text("时间前").tag("Leading")
              Text("时间后").tag("Trailing")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
          }
          labeledPickerRow(title: "AM/PM 字号") {
            Picker("比例", selection: $ampmScale) {
              Text("¼").tag(0.25)
              Text("½").tag(0.5)
              Text("等大").tag(1.0)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
          }
        }
      }
    }
  }

  private var displaySection: some View {
    SettingsSection(title: "显示", systemImage: "display") {
      labeledPickerRow(title: "时间精度") {
        Picker("精度", selection: $timeDisplayPrecisionRaw) {
          ForEach(TimeDisplayPrecision.allCases) { item in
            Text(item.label).tag(item.rawValue)
          }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
      }

      if precision != .minute {
        Label {
          Text("精度越高 CPU 占用越高，屏保常驻建议使用「分」。")
        } icon: {
          Image(systemName: "exclamationmark.triangle.fill")
        }
        .font(.caption)
        .foregroundStyle(.orange.opacity(0.9))
      }

      SettingsToggleRow(title: "显示时区", isOn: $showTimeZoneText)
      SettingsToggleRow(title: "屏保常亮", subtitle: "防止系统自动熄屏", isOn: $keepDisplayAwake)
    }
  }

  private var advancedSection: some View {
    SettingsSection(title: "高级", systemImage: "gearshape") {
      SettingsToggleRow(title: "开发者 Debug", isOn: $showDebugInfo)
    }
  }

  // MARK: - Components

  private var backgroundColorPicker: some View {
    VStack(alignment: .leading, spacing: 14) {
      backgroundPresetRow(title: "深色", presets: BackgroundColorPreset.darkPresets)
      backgroundPresetRow(title: "浅色", presets: BackgroundColorPreset.lightPresets)
    }
  }

  private func backgroundPresetRow(title: String, presets: [BackgroundColorPreset]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.subheadline)
        .foregroundStyle(SettingsTheme.secondaryText)
      HStack(spacing: 12) {
        ForEach(presets) { preset in
          backgroundSwatch(preset: preset)
        }
        Spacer(minLength: 0)
      }
    }
  }

  private func backgroundSwatch(preset: BackgroundColorPreset) -> some View {
    let isSelected = backgroundColorHex == preset.rawValue
    return Button {
      backgroundColorHex = preset.rawValue
    } label: {
      VStack(spacing: 6) {
        Circle()
          .fill(preset.color)
          .frame(width: 40, height: 40)
          .overlay {
            Circle()
              .strokeBorder(
                isSelected
                  ? SettingsTheme.accent
                  : (preset.isLight ? Color.black.opacity(0.15) : Color.white.opacity(0.2)),
                lineWidth: isSelected ? 3 : 1
              )
          }
          .shadow(color: .black.opacity(preset.isLight ? 0.12 : 0.35), radius: 2, y: 1)
        Text(preset.label)
          .font(.caption2)
          .foregroundStyle(isSelected ? .white : SettingsTheme.secondaryText)
      }
    }
    .buttonStyle(.plain)
  }

  private var fontPickerRow: some View {
    Button {
      withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
        showSettings = false
        showFontPicker = true
      }
    } label: {
      HStack {
        Label("字体", systemImage: "textformat")
        Spacer()
        Text(selectedFontName)
          .font(.caption)
          .lineLimit(1)
          .foregroundStyle(SettingsTheme.secondaryText)
        Image(systemName: "chevron.right")
          .font(.caption.weight(.semibold))
          .foregroundStyle(SettingsTheme.secondaryText)
      }
      .padding(.vertical, 4)
    }
    .buttonStyle(.plain)
  }

  #if os(iOS)
    private var footerDoneButton: some View {
      Button(action: closePanel) {
        Text("完成")
          .font(.headline)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
      }
      .buttonStyle(.borderedProminent)
      .padding(.horizontal, 18)
      .padding(.bottom, 16)
      .padding(.top, 8)
    }
  #endif

  private var panelBackground: some View {
    ZStack {
      RoundedRectangle(cornerRadius: SettingsTheme.panelCornerRadius, style: .continuous)
        .fill(.ultraThinMaterial)
      RoundedRectangle(cornerRadius: SettingsTheme.panelCornerRadius, style: .continuous)
        .fill(SettingsTheme.panelBackground.opacity(0.92))
    }
  }

  private func closePanel() {
    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
      showSettings = false
    }
  }

  @ViewBuilder
  private func labeledPickerRow<Content: View>(title: String, @ViewBuilder content: () -> Content)
    -> some View
  {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.subheadline)
        .foregroundStyle(SettingsTheme.secondaryText)
      content()
    }
  }

  @ViewBuilder
  private func settingSlider(
    title: String,
    value: Binding<Double>,
    range: ClosedRange<Double>,
    label: String,
    onEdit: (() -> Void)? = nil
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(title)
          .font(.subheadline)
        Spacer()
        Text(label)
          .font(.subheadline.monospacedDigit())
          .foregroundStyle(SettingsTheme.accent)
      }
      Slider(value: value, in: range)
        .onChange(of: value.wrappedValue) { _, _ in
          onEdit?()
        }
    }
  }
}

// MARK: - Building blocks

private struct SettingsSection<Content: View>: View {
  let title: String
  let systemImage: String
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label(title, systemImage: systemImage)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(SettingsTheme.secondaryText)

      VStack(alignment: .leading, spacing: 16) {
        content
      }
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(SettingsTheme.cardBackground)
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
  }
}

private struct SettingsToggleRow: View {
  let title: String
  var subtitle: String?
  @Binding var isOn: Bool

  var body: some View {
    Toggle(isOn: $isOn) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
        if let subtitle {
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(SettingsTheme.secondaryText)
        }
      }
    }
    #if os(macOS)
      .toggleStyle(.switch)
    #endif
  }
}
