import SwiftUI

extension View {
    /// The bar the home draws, on a page that scrolls: the page's name on the
    /// left and the search on the right, both sent away while the reader
    /// scrolls down and called back by scrolling up, as Safari brings its bar
    /// back. Applied over the page's scroll view, which it watches.
    ///
    /// The page keeps its own `navigationTitle`, for VoiceOver and the Back
    /// button; the bar draws the name itself and none in its middle.
    func scrollAwayBar(_ title: String, onSearch: @escaping () -> Void) -> some View {
        modifier(ScrollAwayBar(title: title, onSearch: onSearch))
    }
}

private struct ScrollAwayBar: ViewModifier {
    let title: String
    let onSearch: () -> Void

    @State private var isCalled = true

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { old, offset in
                // At the very top, or bouncing above it, the bar shows.
                let called = if offset <= 6 { true }
                    else if offset > old + 4 { false }
                    else if offset < old - 4 { true }
                    else { isCalled }
                guard called != isCalled else { return }
                withAnimation(.smooth(duration: 0.25)) { isCalled = called }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { Text(verbatim: "").accessibilityHidden(true) }
                if isCalled {
                    ToolbarItem(placement: .topBarLeading) {
                        Text(verbatim: title)
                            .font(.title2.weight(.bold))
                            .fixedSize()
                            .accessibilityHidden(true)
                    }
                    .sharedBackgroundVisibility(.hidden)
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: onSearch) {
                            Label("Rechercher", systemImage: "magnifyingglass")
                        }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("library-search")
                    }
                }
            }
    }
}
