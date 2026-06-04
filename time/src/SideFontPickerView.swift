import SwiftUI

struct SideFontPickerView: View {
  @Binding var isPresented: Bool
  @Binding var selectedFontName: String
  let allFonts: [String]
  @State private var searchText = ""

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text("字体")
          .font(.title2.weight(.semibold))
        Spacer()
        Button(action: { withAnimation { isPresented = false } }) {
          Image(systemName: "xmark.circle.fill")
            .font(.title2)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
      }
      .padding(.horizontal, 18)
      .padding(.top, 16)
      .padding(.bottom, 12)

      Divider().overlay(SettingsTheme.separator)

      TextField("搜索字体", text: $searchText)
        .textFieldStyle(.roundedBorder)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)

      ScrollView {
        LazyVStack(spacing: 0) {
          let filtered = allFonts.filter {
            searchText.isEmpty || $0.localizedCaseInsensitiveContains(searchText)
          }

          ForEach(filtered, id: \.self) { fontName in
            Button {
              selectedFontName = fontName
            } label: {
              HStack {
                Text(fontName)
                  .font(previewFont(fontName))
                  .foregroundStyle(.white)
                Spacer()
                if selectedFontName == fontName {
                  Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(SettingsTheme.accent)
                }
              }
              .padding(.horizontal, 18)
              .padding(.vertical, 12)
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(
              selectedFontName == fontName
                ? SettingsTheme.accent.opacity(0.15) : Color.clear
            )

            Divider().overlay(SettingsTheme.separator).padding(.leading, 18)
          }
        }
      }
    }
    .foregroundStyle(.white)
    .frame(maxHeight: .infinity)
    .background(
      ZStack {
        RoundedRectangle(cornerRadius: SettingsTheme.panelCornerRadius, style: .continuous)
          .fill(.ultraThinMaterial)
        RoundedRectangle(cornerRadius: SettingsTheme.panelCornerRadius, style: .continuous)
          .fill(SettingsTheme.panelBackground.opacity(0.92))
      }
    )
    .clipShape(RoundedRectangle(cornerRadius: SettingsTheme.panelCornerRadius, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: SettingsTheme.panelCornerRadius, style: .continuous)
        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
    )
    .shadow(color: .black.opacity(0.45), radius: 24, y: 8)
    .environment(\.colorScheme, .dark)
  }

  private func previewFont(_ name: String) -> Font {
    if name == "System Default" { return .system(size: 16) }
    if name == "System Monospaced" { return .system(size: 16, design: .monospaced) }
    return .custom(name, size: 16)
  }
}
