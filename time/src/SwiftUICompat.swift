import SwiftUI

extension View {
  /// iOS 15+ 兼容的 `onChange`（双参数闭包在 iOS 17 才内置）
  @ViewBuilder
  func onChangeCompat<V: Equatable>(
    of value: V,
    perform action: @escaping (_ oldValue: V, _ newValue: V) -> Void
  ) -> some View {
    if #available(iOS 17.0, macOS 14.0, *) {
      onChange(of: value, action)
    } else {
      modifier(LegacyOnChangeModifier(value: value, action: action))
    }
  }

  /// 仅关心新值时的简写
  @ViewBuilder
  func onChangeCompat<V: Equatable>(
    of value: V,
    perform action: @escaping (_ newValue: V) -> Void
  ) -> some View {
    onChangeCompat(of: value) { _, new in action(new) }
  }

  /// 不关心新旧值，仅在变化时执行
  @ViewBuilder
  func onChangeCompat<V: Equatable>(
    of value: V,
    perform action: @escaping () -> Void
  ) -> some View {
    onChangeCompat(of: value) { _, _ in action() }
  }
}

extension View {
  /// 全屏隐藏 Home 指示条等（iOS 16+）
  @ViewBuilder
  func scrollBounceBasedOnSizeIfAvailable() -> some View {
    #if os(iOS)
      if #available(iOS 16.4, *) {
        scrollBounceBehavior(.basedOnSize)
      } else {
        self
      }
    #else
      self
    #endif
  }

  @ViewBuilder
  func hidePersistentSystemOverlaysIfAvailable() -> some View {
    #if os(iOS)
      if #available(iOS 16.0, *) {
        persistentSystemOverlays(.hidden)
      } else {
        self
      }
    #else
      self
    #endif
  }
}

private struct LegacyOnChangeModifier<V: Equatable>: ViewModifier {
  let value: V
  let action: (V, V) -> Void
  @State private var previous: V?

  func body(content: Content) -> some View {
    content
      .onAppear { previous = value }
      .onChange(of: value) { newValue in
        let oldValue = previous ?? newValue
        previous = newValue
        action(oldValue, newValue)
      }
  }
}
