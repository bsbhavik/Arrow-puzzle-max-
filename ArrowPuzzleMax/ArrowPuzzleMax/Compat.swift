import SwiftUI

// Small wrappers so the app runs on iOS 16 while still using the newer APIs on iOS 17+.

extension View {
    /// `onChange` with old and new values on every iOS version.
    @ViewBuilder
    func onChangeCompat<V: Equatable>(of value: V, _ action: @escaping (V, V) -> Void) -> some View {
        if #available(iOS 17, *) {
            onChange(of: value) { old, new in action(old, new) }
        } else {
            modifier(LegacyOnChange(value: value, action: action))
        }
    }

    /// Animated symbol swap (iOS 17+); a plain swap on iOS 16.
    @ViewBuilder
    func replaceSymbolTransition() -> some View {
        if #available(iOS 17, *) {
            contentTransition(.symbolEffect(.replace))
        } else {
            self
        }
    }

    /// Bounces an SF Symbol when `value` changes (iOS 17+); nothing on iOS 16.
    @ViewBuilder
    func bounceSymbol<V: Equatable>(value: V) -> some View {
        if #available(iOS 17, *) {
            symbolEffect(.bounce, value: value)
        } else {
            self
        }
    }

    /// Keeps content at a comfortable width on iPad instead of stretching edge to edge.
    func readableWidth(_ width: CGFloat = 620) -> some View {
        frame(maxWidth: width).frame(maxWidth: .infinity)
    }
}

/// iOS 16 `onChange` only passes the new value, so remember the previous one here.
private struct LegacyOnChange<V: Equatable>: ViewModifier {
    let value: V
    let action: (V, V) -> Void
    @State private var previous: V?

    func body(content: Content) -> some View {
        content
            .onAppear { previous = value }
            .onChange(of: value) { new in
                action(previous ?? new, new)
                previous = new
            }
    }
}
