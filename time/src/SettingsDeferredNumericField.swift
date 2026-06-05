import SwiftUI

/// 设置项数字输入：编辑时用本地草稿，失焦/完成后再写入绑定，避免 iOS 每键重绘卡顿
struct SettingsDeferredNumericField: View {
  @Environment(\.settingsCompactLayout) private var compactLayout

  let title: String
  var hint: String?
  let range: ClosedRange<Double>
  let decimalPlaces: Int
  @Binding var value: Double

  @FocusState private var focused: Bool
  @State private var draft = ""

  var body: some View {
    VStack(alignment: .leading, spacing: compactLayout ? 5 : 8) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(title)
          .font(SettingsTheme.rowLabelFont(compact: compactLayout))
          .foregroundStyle(SettingsTheme.secondaryText)
        Spacer(minLength: 8)
        TextField(placeholder, text: $draft)
          .font(SettingsTheme.rowLabelFont(compact: compactLayout).monospacedDigit())
          .foregroundStyle(SettingsTheme.accent)
          .multilineTextAlignment(.trailing)
          .frame(width: compactLayout ? 72 : 84)
          #if os(iOS)
            .keyboardType(decimalPlaces > 0 ? .decimalPad : .numberPad)
          #endif
          #if os(macOS)
            .textFieldStyle(.roundedBorder)
          #else
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(SettingsTheme.cardBackground.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
          #endif
          .focused($focused)
          .onSubmit { commitDraft() }
      }
      if let hint {
        Text(hint)
          .font(compactLayout ? .caption2 : .caption)
          .foregroundStyle(SettingsTheme.secondaryText)
      }
    }
    .onAppear { syncDraftFromValue() }
    .onChangeCompat(of: value) { _, _ in
      guard !focused else { return }
      syncDraftFromValue()
    }
    .onChangeCompat(of: focused) { _, isFocused in
      if !isFocused { commitDraft() }
    }
  }

  private var placeholder: String {
    decimalPlaces > 0 ? "0.\(String(repeating: "0", count: decimalPlaces))" : "0"
  }

  private func syncDraftFromValue() {
    draft = Self.format(value, decimalPlaces: decimalPlaces)
  }

  private func commitDraft() {
    let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let parsed = Self.parse(trimmed) else {
      syncDraftFromValue()
      return
    }
    let clamped = Self.clamp(parsed, in: range, decimalPlaces: decimalPlaces)
    if clamped != value {
      value = clamped
    }
    draft = Self.format(clamped, decimalPlaces: decimalPlaces)
  }

  static func parse(_ text: String) -> Double? {
    let normalized = text.replacingOccurrences(of: ",", with: ".")
    guard !normalized.isEmpty else { return nil }
    return Double(normalized)
  }

  static func clamp(_ value: Double, in range: ClosedRange<Double>, decimalPlaces: Int) -> Double {
    let bounded = min(max(value, range.lowerBound), range.upperBound)
    guard decimalPlaces > 0 else { return bounded.rounded() }
    let factor = pow(10.0, Double(decimalPlaces))
    return (bounded * factor).rounded() / factor
  }

  static func format(_ value: Double, decimalPlaces: Int) -> String {
    if decimalPlaces == 0 {
      return String(Int(value.rounded()))
    }
    return String(format: "%.\(decimalPlaces)f", value)
  }
}
