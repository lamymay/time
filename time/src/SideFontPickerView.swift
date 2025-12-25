import SwiftUI

struct SideFontPickerView: View {
  @Binding var isPresented: Bool
  @Binding var selectedFontName: String
  let allFonts: [String]
  @State private var searchText = ""

  var body: some View {
    VStack(spacing: 0) {
      // ... 顶部和搜索框保持不变 ...

      ScrollView {
        LazyVStack(spacing: 0) {
          let filtered = allFonts.filter {
            searchText.isEmpty || $0.localizedCaseInsensitiveContains(searchText)
          }

          ForEach(filtered, id: \.self) { fontName in
            Button(action: {
              // 优化点：使用 Task 异步更新，防止主线程因字体加载瞬间锁死
              Task {
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
            .background(selectedFontName == fontName ? Color.blue.opacity(0.25) : Color.clear)

            Divider().background(Color.white.opacity(0.1))
          }
        }
      }
    }
    .background(.ultraThinMaterial)
    .environment(\.colorScheme, .dark)
  }

  private func previewFont(_ name: String) -> Font {
    // 预设字体的快速路径
    if name == "System Default" { return .system(size: 16) }
    if name == "System Monospaced" { return .system(size: 16, design: .monospaced) }

    // 这里的 custom 实例化在 iOS 上如果字体文件很大可能会卡
    // 保持 size 统一且较小有助于性能
    return .custom(name, size: 16)
  }
}
