import SwiftUI

/// 全屏设置顶部的实时时钟预览（只读 segments，不抢占 tick target）
struct SettingsClockPreview: View {
  let segments: TimeSegments
  let displayStyle: ClockDisplayStyle
  let config: ClockDisplayConfig
  let backgroundColorHex: String
  let flipCardColorHex: String
  let fontColorHex: String
  let ampmVertical: String
  let showTimeZoneText: Bool
  let previewSize: CGSize

  private var previewConfig: ClockDisplayConfig {
    config.applyingDisplayStyle(displayStyle)
  }

  var body: some View {
    ZStack {
      Color(hex: ColorPickerCodec.normalizedHex(backgroundColorHex))
      clockContent
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
    .frame(height: previewSize.height)
    .frame(maxWidth: .infinity)
    .accessibilityLabel(L10n.text("settings.clock_preview"))
  }

  @ViewBuilder
  private var clockContent: some View {
    switch displayStyle {
    case .classic:
      classicPreview
    case .flip:
      FlipClockPreview(
        segments: segments,
        config: previewConfig,
        backgroundColorHex: backgroundColorHex,
        flipCardColorHex: flipCardColorHex,
        fontColorHex: fontColorHex,
        previewSize: previewSize
      )
    }
  }

  private var classicPreview: some View {
    let effectiveSize = ClockFontSizeLimits.classicEffectiveFontSize(
      configured: previewConfig.fontSize,
      screen: previewSize,
      config: previewConfig
    )
    let style = NativeClockStyle.resolve(
      fontSize: Double(effectiveSize),
      ampmScale: previewConfig.ampmScale,
      fontName: previewConfig.selectedFontName
    )
    let stamp = ClockStyleStamp(
      style: style,
      precision: previewConfig.displayPrecision,
      timeZoneTopGap: -style.timeZoneSize * 0.12,
      color: Color(hex: ColorPickerCodec.normalizedHex(fontColorHex)),
      showTimeZoneText: showTimeZoneText,
      ampmVertical: ampmVertical
    )
    return NativeClockPreviewRepresentable(segments: segments, styleStamp: stamp)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
  }
}
