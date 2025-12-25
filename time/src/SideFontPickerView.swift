import SwiftUI

struct SideFontPickerView: View {
  @Binding var isPresented: Bool
  @Binding var selectedFontName: String
  let allFonts: [String]
  @State private var searchText = ""

  var body: some View {
    VStack(spacing: 0) {
      // 顶部导航 (保持不变)
      HStack {
        Text("字体预览").font(.headline).foregroundColor(.white)
        Spacer()
        Button(action: { withAnimation(.spring()) { isPresented = false } }) {
          Image(systemName: "xmark.circle.fill")
            .font(.title2)
            .foregroundColor(.gray.opacity(0.8))
        }
      }
      .padding()
      .background(Color.white.opacity(0.05))

      // 搜索框
      TextField("", text: $searchText, prompt: Text("搜索字体...").foregroundColor(.gray))
        .padding(10)
        .background(Color.white.opacity(0.12))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .foregroundColor(.white)

      // 关键优化：使用 ScrollView + LazyVStack 代替 List
      ScrollView {
        LazyVStack(spacing: 0) {
          let filtered = allFonts.filter {
            searchText.isEmpty || $0.localizedCaseInsensitiveContains(searchText)
          }

          ForEach(filtered, id: \.self) { fontName in
            Button(action: { selectedFontName = fontName }) {
              HStack {
                Text(fontName)
                  .font(previewFont(fontName))
                  .foregroundColor(.white)
                  .lineLimit(1)
                Spacer()
                if selectedFontName == fontName {
                  Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                }
              }
              .padding(.horizontal)
              .padding(.vertical, 10)
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(selectedFontName == fontName ? Color.blue.opacity(0.25) : Color.clear)

            Divider().background(Color.white.opacity(0.05))
          }
        }
      }
    }
    .frame(width: 300)
    .background(.ultraThinMaterial)
    .environment(\.colorScheme, .dark)
  }

  // 性能优化逻辑：避免复杂字体的过度计算
  private func previewFont(_ name: String) -> Font {
    // 内置字体快速返回
    if name == "System Default" { return .system(size: 15) }
    if name.contains("Monospaced") { return .system(size: 15, design: .monospaced) }

    // 如果列表字体太多，限制预览大小，减少内存占用
    return .custom(name, size: 15)
  }
}
