import SwiftUI

struct SideFontPickerView: View {
  @Binding var isPresented: Bool
  @Binding var selectedFontName: String
  let allFonts: [String]
  @State private var searchText = ""

  var body: some View {
    VStack(spacing: 0) {
      // 顶部栏
      HStack {
        Text("字体样式").font(.headline)
        Spacer()
        Button(action: { withAnimation { isPresented = false } }) {
          Image(systemName: "xmark.circle.fill")
            .font(.title2)
            .foregroundColor(.gray)
        }
      }
      .padding()
      .background(Color.white.opacity(0.05))

      // 搜索框
      TextField("搜索字体...", text: $searchText)
        .padding(8)
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
        .padding()

      ScrollView {
        LazyVStack(spacing: 0) {
          let filtered = allFonts.filter {
            searchText.isEmpty || $0.localizedCaseInsensitiveContains(searchText)
          }

          ForEach(filtered, id: \.self) { fontName in
            Button(action: {
              Task { @MainActor in
                selectedFontName = fontName
              }
            }) {
              HStack {
                Text(fontName)
                  .font(previewFont(fontName))
                  .foregroundColor(.white)
                Spacer()
                if selectedFontName == fontName {
                  Image(systemName: "checkmark.circle.fill").foregroundColor(.blue)
                }
              }
              .padding(.horizontal)
              .padding(.vertical, 12)
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(selectedFontName == fontName ? Color.blue.opacity(0.2) : Color.clear)

            Divider().background(Color.white.opacity(0.1))
          }
        }
      }
    }
    .frame(maxHeight: .infinity)  // 确保撑满屏幕高度
    .background(.ultraThinMaterial)
    .environment(\.colorScheme, .dark)
  }

  private func previewFont(_ name: String) -> Font {
    if name == "System Default" { return .system(size: 16) }
    if name == "System Monospaced" { return .system(size: 16, design: .monospaced) }
    return .custom(name, size: 16)
  }
}
