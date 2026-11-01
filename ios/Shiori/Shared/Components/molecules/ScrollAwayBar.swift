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

    @State private var bar = ScrollBarState()

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { old, offset in
                // At the very top, or bouncing above it, the bar shows.
                if offset <= 6 {
                    bar.call(true)
                } else if offset > old + 4 {
                    bar.call(false)
                } else if offset < old - 4 {
                    bar.call(true)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { Text(verbatim: "").accessibilityHidden(true) }
                ToolbarItem(placement: .topBarLeading) {
                    ScrollBarItem(bar: bar) {
                        Text(verbatim: title)
                            .font(.title2.weight(.bold))
                            .fixedSize()
                            .accessibilityHidden(true)
                    }
                }
                .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .topBarTrailing) {
                    ScrollBarItem(bar: bar) {
                        ScrollBarButton(title: "Rechercher", systemImage: "magnifyingglass", action: onSearch)
                            .accessibilityIdentifier("library-search")
                    }
                }
                .sharedBackgroundVisibility(.hidden)
            }
    }
}

/// Whether a bar that scrolls away is called, and whether its page has left
/// the top. Held in a class, and read only by the items that fade: on the
/// page's own state, each call rebuilt the page and every item of the bar,
/// a burst of late frames on each change of direction.
@MainActor
@Observable
final class ScrollBarState {
    private(set) var isCalled: Bool
    private(set) var hasLeftTop = false

    init(isCalled: Bool = true) {
        self.isCalled = isCalled
    }

    func call(_ called: Bool) {
        guard called != isCalled else { return }
        withAnimation(.smooth(duration: 0.25)) { isCalled = called }
    }

    func leaveTop(_ left: Bool) {
        guard left != hasLeftTop else { return }
        hasLeftTop = left
    }
}

/// An item of a bar that scrolls away. The item stays in the bar and only
/// fades: taking it out and back made the system lay the bar out again in the
/// middle of the scroll. Hide the item's shared glass, which would not fade
/// with it, and give it its own, as `ScrollBarButton` does.
struct ScrollBarItem<Content: View>: View {
    let bar: ScrollBarState
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .opacity(bar.isCalled ? 1 : 0)
            .allowsHitTesting(bar.isCalled)
            .accessibilityHidden(!bar.isCalled)
    }
}

/// A round bar button carrying its own glass, at the avatar's size.
struct ScrollBarButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.medium))
                .frame(width: 44, height: 44)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
