import SwiftUI

enum SettingsPanelLayout {
  case sidePanel
  case bottomSheet
}

struct SettingsPanelView: View {
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
  @Binding var fontColorHex: String
  @Binding var flipCardColorHex: String
  @Binding var keepDisplayAwake: Bool
  @Binding var oledPixelShiftEnabled: Bool

  let layout: SettingsPanelLayout
  @Binding var panelOffset: CGSize
  @Binding var settingsSheetWidth: Double
  var onSpeedChange: () -> Void

  @GestureState private var dragOffset: CGSize = .zero
  @State private var showEmailCopiedAlert = false
  @State private var widthAtResizeStart: CGFloat?

  private var precision: TimeDisplayPrecision {
    TimeDisplayPrecision.resolved(fromRaw: timeDisplayPrecisionRaw)
  }

  private var displayStyle: ClockDisplayStyle {
    ClockDisplayStyle(rawValue: clockDisplayStyleRaw) ?? .classic
  }

  private var panelClockConfig: ClockDisplayConfig {
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
      displayPrecision: precision,
      flipFormat: FlipClockFormat.resolved(fromRaw: flipClockFormatRaw),
      flipCompactDetachedSeconds: flipCompactDetachedSeconds
    )
  }

  private var fontSizeRange: ClosedRange<Double> {
    ClockFontSizeLimits.sliderRange(
      style: displayStyle,
      screen: screenSize,
      config: panelClockConfig
    )
  }

  private func syncFontSizeToLimits() {
    ClockFontSizeLimits.clampStoredFontSize(
      &fontSize,
      style: displayStyle,
      screen: screenSize,
      config: panelClockConfig
    )
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          fontSizeSection
          fontSection
          clockAppearanceSection
          timeFormatSection
          systemSection
          supportSection
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
    .onAppear { syncFontSizeToLimits() }
    .onChange(of: screenSize) { _, _ in syncFontSizeToLimits() }
    .onChange(of: clockDisplayStyleRaw) { _, _ in syncFontSizeToLimits() }
    .onChange(of: flipClockFormatRaw) { _, _ in syncFontSizeToLimits() }
    .onChange(of: flipCompactDetachedSeconds) { _, _ in syncFontSizeToLimits() }
    .onChange(of: panelClockConfig) { _, _ in syncFontSizeToLimits() }
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
      .frame(minWidth: SettingsPanelMetrics.macMinWidth, idealWidth: SettingsPanelMetrics.macIdealWidth)
    #endif
    #if os(iOS)
      .overlay(alignment: .trailing) {
        if layout == .bottomSheet {
          iosSheetWidthResizeHandle
        }
      }
    #endif
    .accessibilityIdentifier(TimeAccessibilityID.settingsPanel)
    .alert(L10n.text("feedback.copy_title"), isPresented: $showEmailCopiedAlert) {
      Button(L10n.text("settings.done"), role: .cancel) {}
    } message: {
      Text(L10n.text("feedback.copy_message"))
    }
  }

  // MARK: - Header

  private var header: some View {
    VStack(spacing: 0) {
      dragHandle

      HStack(alignment: .center) {
        Text(L10n.text("settings.title"))
          .font(.title2.weight(.semibold))
        Spacer()
        Button(action: closePanel) {
          Image(systemName: "xmark.circle.fill")
            .font(.title2)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(TimeAccessibilityID.settingsCloseButton)
        #if os(macOS)
          .keyboardShortcut(.escape, modifiers: [])
          .help(L10n.text("settings.close_help"))
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
    .accessibilityLabel(L10n.text("settings.drag_handle"))
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

  #if os(iOS)
    private var iosSheetResolvedWidth: CGFloat {
      SettingsPanelMetrics.resolvedIOSSheetWidth(stored: settingsSheetWidth, screen: screenSize)
    }

    private var iosSheetWidthResizeHandle: some View {
      HStack(spacing: 0) {
        Capsule()
          .fill(Color.white.opacity(0.22))
          .frame(width: 3, height: 36)
        Image(systemName: "arrow.left.and.right")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(SettingsTheme.secondaryText)
          .padding(.leading, 4)
      }
      .frame(width: 28)
      .frame(maxHeight: .infinity)
      .contentShape(Rectangle())
      .gesture(iosSheetWidthResizeGesture)
      .accessibilityLabel(L10n.text("settings.resize_panel_width"))
      .padding(.trailing, 4)
    }

    private var iosSheetWidthResizeGesture: some Gesture {
      DragGesture(minimumDistance: 2)
        .onChanged { value in
          if widthAtResizeStart == nil {
            widthAtResizeStart = iosSheetResolvedWidth
          }
          guard let start = widthAtResizeStart else { return }
          let next = SettingsPanelMetrics.clampIOSSheetWidth(
            start + value.translation.width,
            screen: screenSize
          )
          settingsSheetWidth = Double(next)
        }
        .onEnded { _ in
          widthAtResizeStart = nil
        }
    }
  #endif

  // MARK: - Sections

  private var fontSizeSection: some View {
    SettingsInlineSection(title: L10n.text("settings.font_size"), systemImage: "textformat.size") {
      Slider(value: $fontSize, in: fontSizeRange)
      Text("\(Int(fontSize))")
        .font(.subheadline.monospacedDigit())
        .foregroundStyle(SettingsTheme.accent)
        .frame(minWidth: 40, alignment: .trailing)
    }
  }

  private var fontSection: some View {
    SettingsInlineSection(title: L10n.text("settings.font"), systemImage: "textformat") {
      fontPickerRow
    }
  }

  private var clockAppearanceSection: some View {
    SettingsSection(title: L10n.text("settings.clock_appearance"), systemImage: "clock") {
      Picker(selection: $clockDisplayStyleRaw) {
        ForEach(ClockDisplayStyle.allCases) { style in
          Text(style.label).tag(style.rawValue)
        }
      } label: {
        EmptyView()
      }
      .pickerStyle(.segmented)
      .labelsHidden()

      SettingsClockPreview(
        config: panelClockConfig,
        style: displayStyle,
        backgroundColorHex: backgroundColorHex,
        flipCardColorHex: flipCardColorHex,
        fontColorHex: fontColorHex
      )

      if displayStyle == .flip {
        ColorPlanePicker(
          title: L10n.text("settings.clock_color"),
          colorHex: $flipCardColorHex,
          saturation: 0.35
        )
      }
      ColorPlanePicker(
        title: L10n.text("settings.background_color"),
        colorHex: $backgroundColorHex
      )
      backgroundPureBlackShortcut
      ColorPlanePicker(
        title: L10n.text("settings.font_color"),
        colorHex: $fontColorHex,
        saturation: 0.82
      )

      if displayStyle == .flip {
        labeledPickerRow(title: L10n.text("settings.flip_format")) {
          Picker(L10n.text("settings.flip_format"), selection: $flipClockFormatRaw) {
            ForEach(FlipClockFormat.allCases) { format in
              Text(format.label).tag(format.rawValue)
            }
          }
          .pickerStyle(.segmented)
          .labelsHidden()
        }
        Text(FlipClockFormat.resolved(fromRaw: flipClockFormatRaw).subtitle)
          .font(.caption)
          .foregroundStyle(SettingsTheme.secondaryText)

        if FlipClockFormat.resolved(fromRaw: flipClockFormatRaw) == .compactPanels,
          precision.includesSeconds
        {
          SettingsToggleRow(
            title: L10n.text("settings.flip_compact_detached_seconds"),
            subtitle: L10n.text("settings.flip_compact_detached_seconds_hint"),
            isOn: $flipCompactDetachedSeconds
          )
        }
      }

      labeledPickerRow(title: L10n.text("settings.time_precision")) {
        Picker(L10n.text("settings.time_precision"), selection: $timeDisplayPrecisionRaw) {
          ForEach(TimeDisplayPrecision.allCases) { item in
            Text(item.label).tag(item.rawValue)
          }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
      }

      if precision != .minute {
        Label {
          Text(L10n.text("settings.precision_warning"))
        } icon: {
          Image(systemName: "exclamationmark.triangle.fill")
        }
        .font(.caption)
        .foregroundStyle(.orange.opacity(0.9))
      }

      SettingsToggleRow(title: L10n.text("settings.show_timezone"), isOn: $showTimeZoneText)

      if displayStyle == .classic {
        settingSlider(
          title: L10n.text("settings.move_speed"),
          value: $moveSpeed,
          range: MoveSpeedLimits.min...MoveSpeedLimits.max,
          label: MoveSpeedLimits.displayLabel(for: moveSpeed)
        ) { onSpeedChange() }
        Text(L10n.text("settings.motion_hint"))
          .font(.caption)
          .foregroundStyle(SettingsTheme.secondaryText)
      }
    }
  }

  private var backgroundPureBlackShortcut: some View {
    let isPureBlack =
      BackgroundColorPreset.from(hex: backgroundColorHex) == .black
      || ColorPickerCodec.normalizedHex(backgroundColorHex) == BackgroundColorPreset.black.rawValue

    return Button {
      backgroundColorHex = BackgroundColorPreset.black.rawValue
    } label: {
      HStack(spacing: 12) {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(Color.black)
          .frame(width: 32, height: 32)
          .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
          )
        Text(L10n.text("settings.background_pure_black"))
          .foregroundStyle(.primary)
        Spacer()
        if isPureBlack {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(SettingsTheme.accent)
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .background(SettingsTheme.cardBackground)
      .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private var timeFormatSection: some View {
    SettingsSection(title: L10n.text("settings.time"), systemImage: "clock") {
      labeledPickerRow(title: L10n.text("settings.time_format")) {
        Picker(L10n.text("settings.time_format"), selection: $is24Hour) {
          Text(L10n.text("format.12h")).tag(false)
          Text(L10n.text("format.24h")).tag(true)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
      }

      SettingsToggleRow(title: L10n.text("settings.hour_pad_zero"), isOn: $padZero)

      if !is24Hour {
        SettingsToggleRow(title: L10n.text("settings.show_ampm"), isOn: $showAMPM)
        if showAMPM {
          labeledPickerRow(title: L10n.text("settings.ampm_position")) {
            Picker(L10n.text("settings.ampm_position"), selection: $ampmSide) {
              Text(L10n.text("format.ampm_before")).tag("Leading")
              Text(L10n.text("format.ampm_after")).tag("Trailing")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
          }
          labeledPickerRow(title: L10n.text("settings.ampm_scale")) {
            Picker(L10n.text("settings.ampm_scale"), selection: $ampmScale) {
              Text(L10n.text("format.ampm_quarter")).tag(0.25)
              Text(L10n.text("format.ampm_half")).tag(0.5)
              Text(L10n.text("format.ampm_equal")).tag(1.0)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
          }
        }
      }
    }
  }

  private var systemSection: some View {
    SettingsSection(title: L10n.text("settings.display"), systemImage: "display") {
      SettingsToggleRow(
        title: L10n.text("settings.keep_awake"),
        subtitle: L10n.text("settings.keep_awake_hint"),
        isOn: $keepDisplayAwake
      )
      SettingsToggleRow(
        title: L10n.text("settings.oled_pixel_shift"),
        subtitle: L10n.text("settings.oled_pixel_shift_hint"),
        isOn: $oledPixelShiftEnabled
      )
    }
  }

  private var supportSection: some View {
    SettingsSection(title: L10n.text("settings.support"), systemImage: "envelope") {
      HStack(alignment: .center, spacing: 8) {
        Button(action: openFeedbackMail) {
          HStack {
            VStack(alignment: .leading, spacing: 2) {
              Text(L10n.text("settings.feedback"))
              Text(FeedbackMail.developerEmail)
                .font(.caption)
                .foregroundStyle(SettingsTheme.secondaryText)
            }
            Spacer()
            Image(systemName: "envelope.arrow.triangle.branch")
              .font(.caption.weight(.semibold))
              .foregroundStyle(SettingsTheme.secondaryText)
          }
          .padding(.vertical, 4)
        }
        .buttonStyle(.plain)

        Button(action: copyFeedbackEmail) {
          Image(systemName: "doc.on.doc")
            .font(.body)
            .foregroundStyle(SettingsTheme.accent)
            .padding(8)
            .background(SettingsTheme.cardBackground.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        #if os(macOS)
          .help(L10n.text("feedback.copy_button_hint"))
        #else
          .accessibilityLabel(L10n.text("feedback.copy_button_hint"))
        #endif
      }
    }
  }

  private func openFeedbackMail() {
    FeedbackMail.requestFeedback { result in
      if result == .copiedAddress {
        showEmailCopiedAlert = true
      }
    }
  }

  private func copyFeedbackEmail() {
    FeedbackMail.copyDeveloperEmail()
    showEmailCopiedAlert = true
  }

  private var advancedSection: some View {
    SettingsSection(title: L10n.text("settings.advanced"), systemImage: "gearshape") {
      SettingsToggleRow(title: L10n.text("settings.debug"), isOn: $showDebugInfo)
    }
  }

  // MARK: - Components

  private var fontPickerRow: some View {
    Button {
      withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
        showSettings = false
        showFontPicker = true
      }
    } label: {
      HStack(spacing: 6) {
        Spacer(minLength: 0)
        Text(selectedFontName)
          .font(.subheadline)
          .lineLimit(1)
          .foregroundStyle(SettingsTheme.secondaryText)
        Image(systemName: "chevron.right")
          .font(.caption.weight(.semibold))
          .foregroundStyle(SettingsTheme.secondaryText)
      }
    }
    .buttonStyle(.plain)
  }

  #if os(iOS)
    private var footerDoneButton: some View {
      Button(action: closePanel) {
        Text(L10n.text("settings.done"))
          .font(.headline)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
      }
      .buttonStyle(.borderedProminent)
      .accessibilityIdentifier(TimeAccessibilityID.settingsDoneButton)
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

/// 标题与控件同一行（字号、字体等）
private struct SettingsInlineSection<Content: View>: View {
  let title: String
  let systemImage: String
  @ViewBuilder let content: Content

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      Label(title, systemImage: systemImage)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(SettingsTheme.secondaryText)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)

      content
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(SettingsTheme.cardBackground)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
