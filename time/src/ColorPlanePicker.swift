import SwiftUI

/// 二维色条：左右色相、上下明暗
struct ColorPlanePicker: View {
  let title: String
  @Binding var colorHex: String
  var saturation: Double = ColorPickerCodec.defaultSaturation

  private let planeHeight: CGFloat = 128
  private let previewSize: CGFloat = 44
  private let inset: CGFloat = 10

  @State private var liveHue: Double?
  @State private var liveBrightness: Double?

  private var normalizedHex: String {
    ColorPickerCodec.normalizedHex(colorHex)
  }

  private var displayHue: Double {
    liveHue ?? Color(hex: normalizedHex).pickerHue
  }

  private var displayBrightness: Double {
    liveBrightness ?? Color(hex: normalizedHex).pickerBrightness
  }

  private var previewColor: Color {
    Color(hex: normalizedHex)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title)
        .font(.subheadline)
        .foregroundStyle(SettingsTheme.secondaryText)

      HStack(alignment: .center, spacing: 12) {
        colorPlane
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(previewColor)
          .frame(width: previewSize, height: planeHeight)
          .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
              .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
          }
      }

      HStack(spacing: 16) {
        hintLabel(L10n.text("color.picker_hue"), systemImage: "arrow.left.and.right")
        hintLabel(L10n.text("color.picker_brightness"), systemImage: "arrow.up.and.down")
      }
      .font(.caption2)
      .foregroundStyle(SettingsTheme.secondaryText)
    }
  }

  private func hintLabel(_ text: String, systemImage: String) -> some View {
    Label(text, systemImage: systemImage)
      .labelStyle(.titleAndIcon)
  }

  private var colorPlane: some View {
    GeometryReader { geo in
      let size = geo.size
      let point = crosshairPoint(in: size)

      ZStack {
        colorField
          .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)

        crosshair
          .position(point)
      }
      .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            apply(location: value.location, in: size)
          }
          .onEnded { value in
            apply(location: value.location, in: size)
            liveHue = nil
            liveBrightness = nil
          }
      )
    }
    .frame(height: planeHeight)
  }

  private var colorField: some View {
    ZStack {
      LinearGradient(
        colors: hueStops,
        startPoint: .leading,
        endPoint: .trailing
      )
      LinearGradient(
        colors: [.white, .black],
        startPoint: .top,
        endPoint: .bottom
      )
      .blendMode(.multiply)
    }
  }

  private var hueStops: [Color] {
    stride(from: 0.0, through: 1.0, by: 0.05).map { step in
      Color(hue: step, saturation: saturation, brightness: 1)
    }
  }

  private var crosshair: some View {
    ZStack {
      Circle()
        .strokeBorder(.white, lineWidth: 2.5)
        .background(Circle().fill(.white.opacity(0.25)))
        .frame(width: 18, height: 18)
      Circle()
        .strokeBorder(.black.opacity(0.35), lineWidth: 1)
        .frame(width: 20, height: 20)
    }
    .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
    .allowsHitTesting(false)
  }

  private func crosshairPoint(in size: CGSize) -> CGPoint {
    let usableW = max(size.width - inset * 2, 1)
    let usableH = max(size.height - inset * 2, 1)
    let x = inset + CGFloat(displayHue.clamped(to: 0...1)) * usableW
    let y = inset + CGFloat(1 - displayBrightness.clamped(to: 0...1)) * usableH
    return CGPoint(x: x, y: y)
  }

  private func apply(location: CGPoint, in size: CGSize) {
    let usableW = max(size.width - inset * 2, 1)
    let usableH = max(size.height - inset * 2, 1)
    let x = min(max(location.x - inset, 0), usableW)
    let y = min(max(location.y - inset, 0), usableH)
    let hue = Double(x / usableW)
    let brightness = 1 - Double(y / usableH)
    liveHue = hue
    liveBrightness = brightness
    colorHex = ColorPickerCodec.hex(
      hue: hue,
      brightness: brightness,
      saturation: saturation
    )
  }
}

private extension Comparable {
  func clamped(to range: ClosedRange<Self>) -> Self {
    min(max(self, range.lowerBound), range.upperBound)
  }
}
