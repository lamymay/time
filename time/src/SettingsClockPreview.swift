import SwiftUI

/// 设置面板内的缩小时钟预览（独立 scheduler，不与主屏争用 tick target）
struct SettingsClockPreview: View {
  let config: ClockDisplayConfig
  let style: ClockDisplayStyle
  let backgroundColorHex: String
  let flipCardColorHex: String
  let fontColorHex: String

  @State private var previewScheduler = ClockTimeScheduler()

  private var previewConfig: ClockDisplayConfig {
    var c = config
    c.fontSize = min(config.fontSize * 0.2, 72)
    c.showTimeZoneText = false
    return c
  }

  var body: some View {
    ZStack {
      Color(hex: ColorPickerCodec.normalizedHex(backgroundColorHex))
      Group {
        switch style {
        case .flip:
          FlipClockScene(
            scheduler: previewScheduler,
            config: previewConfig,
            backgroundColorHex: backgroundColorHex,
            flipCardColorHex: flipCardColorHex,
            fontColorHex: fontColorHex,
            isActive: true
          )
        case .classic:
          SettingsClassicClockPreview(
            config: previewConfig,
            fontColorHex: fontColorHex
          )
        }
      }
    }
    .frame(height: 120)
    .frame(maxWidth: .infinity)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
    )
    .accessibilityIdentifier(TimeAccessibilityID.settingsClockPreview)
    .onAppear { syncPreviewScheduler() }
    .onChange(of: config) { _, _ in syncPreviewScheduler() }
  }

  private func syncPreviewScheduler() {
    previewScheduler.setFormat(previewConfig.schedulerFormatOptions)
    previewScheduler.setActive(true)
  }
}

private struct SettingsClassicClockPreview: View {
  let config: ClockDisplayConfig
  let fontColorHex: String

  private var nativeStyle: NativeClockStyle {
    NativeClockStyle.resolve(
      fontSize: config.fontSize,
      ampmScale: config.ampmScale,
      fontName: config.selectedFontName
    )
  }

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
      let segments = TimeProvider.segments(from: timeline.date, format: config.formatOptions)
      let color = Color(hex: ColorPickerCodec.normalizedHex(fontColorHex))
      Text(Self.previewTimeString(segments: segments, config: config))
        .font(
          .custom(
            config.selectedFontName,
            size: nativeStyle.fontSize,
            relativeTo: .largeTitle
          )
          .weight(.bold)
        )
        .foregroundStyle(color)
        .minimumScaleFactor(0.35)
        .lineLimit(1)
        .padding(.horizontal, 8)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private static func previewTimeString(segments: TimeSegments, config: ClockDisplayConfig) -> String {
    var text = ""
    if !segments.leadingAMPM.isEmpty {
      text += segments.leadingAMPM + " "
    }
    let hour = segments.hourTens + segments.hourOnes
    let minute = segments.minuteTens + segments.minuteOnes
    text += hour + ":" + minute
    if config.displayPrecision.includesSeconds {
      text += ":" + segments.secondTens + segments.secondOnes
    }
    if !segments.trailingAMPM.isEmpty {
      text += " " + segments.trailingAMPM
    }
    return text
  }
}
