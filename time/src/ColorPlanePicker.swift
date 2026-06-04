import SwiftUI

/// 二维色条：左右色相、上下明暗
struct ColorPlanePicker: View {
  let title: String
  @Binding var colorHex: String
  var saturation: Double = ColorPickerCodec.defaultSaturation

  private let planeHeight: CGFloat = 128
  private let inset: CGFloat = 10

  @State private var liveHue: Double?
  @State private var liveBrightness: Double?

  private var normalizedHex: String {
    ColorPickerCodec.normalizedHex(colorHex)
  }

  /// 色条最左为黄（HSB 约 60°），向右扫完整色相环
  private static let huePlaneOrigin: Double = 1.0 / 6.0

  private var displayHue: Double {
    liveHue ?? Color(hex: normalizedHex).pickerHue
  }

  private var displayPlaneHue: Double {
    planeHue(from: displayHue)
  }

  private var displayBrightness: Double {
    liveBrightness ?? Color(hex: normalizedHex).pickerBrightness
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.subheadline)
        .foregroundStyle(SettingsTheme.secondaryText)

      colorPlane
    }
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
    .frame(maxWidth: .infinity)
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
    stride(from: 0.0, through: 1.0, by: 0.05).map { planeHue in
      Color(
        hue: actualHue(from: planeHue),
        saturation: saturation,
        brightness: 1
      )
    }
  }

  private func actualHue(from planeHue: Double) -> Double {
    (planeHue + Self.huePlaneOrigin).truncatingRemainder(dividingBy: 1)
  }

  private func planeHue(from actualHue: Double) -> Double {
    var plane = actualHue - Self.huePlaneOrigin
    if plane < 0 { plane += 1 }
    return plane
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
    let x = inset + CGFloat(displayPlaneHue.clamped(to: 0...1)) * usableW
    let y = inset + CGFloat(1 - displayBrightness.clamped(to: 0...1)) * usableH
    return CGPoint(x: x, y: y)
  }

  private func apply(location: CGPoint, in size: CGSize) {
    let usableW = max(size.width - inset * 2, 1)
    let usableH = max(size.height - inset * 2, 1)
    let x = min(max(location.x - inset, 0), usableW)
    let y = min(max(location.y - inset, 0), usableH)
    let planeHue = Double(x / usableW)
    let hue = actualHue(from: planeHue)
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

/// 色条操作说明（设置里整组颜色只显示一次）
struct ColorPlanePickerHints: View {
  var body: some View {
    HStack(spacing: 16) {
      Label(L10n.text("color.picker_hue"), systemImage: "arrow.left.and.right")
      Label(L10n.text("color.picker_brightness"), systemImage: "arrow.up.and.down")
    }
    .font(.caption2)
    .foregroundStyle(SettingsTheme.secondaryText)
    .labelStyle(.titleAndIcon)
  }
}

private extension Comparable {
  func clamped(to range: ClosedRange<Self>) -> Self {
    min(max(self, range.lowerBound), range.upperBound)
  }
}
