import SwiftUI

extension View {
    /// The bar the home draws, on a page that scrolls: the page's name on the
    /// left, the page's buttons on the right, each on its own glass, all sent
    /// away together while the reader scrolls down and called back by
    /// scrolling up, as Safari brings its bar back. The bar has no ground of
    /// its own: the page runs under it. Applied over the page, whose scroll
    /// view it watches.
    ///
    /// The page keeps its own `navigationTitle`, for VoiceOver and the Back
    /// button; the bar draws the name itself and none in its middle.
    func scrollAwayBar(_ title: String) -> some View {
        modifier(ScrollAwayBar(title: title, trailing: EmptyView()))
    }

    /// The same bar with the page's buttons on the right, the avatar last.
    func scrollAwayBar<Trailing: View>(
        _ title: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        modifier(ScrollAwayBar(title: title, trailing: trailing()))
    }
}

private struct ScrollAwayBar<Trailing: View>: ViewModifier {
    let title: String
    let trailing: Trailing

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
            // The bar stays clear over the page, as the TV app's does.
            .scrollEdgeEffectHidden(true, for: .top)
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
                if Trailing.self != EmptyView.self {
                    ToolbarItem(placement: .topBarTrailing) {
                        ScrollBarItem(bar: bar) {
                            HStack(spacing: 10) { trailing }
                        }
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
            }
    }
}

/// Whether a bar that scrolls away is called. Held in a class, and read only by the items that fade: on the
/// page's own state, each call rebuilt the page and every item of the bar,
/// a burst of late frames on each change of direction.
@MainActor
@Observable
final class ScrollBarState {
    private(set) var isCalled: Bool

    init(isCalled: Bool = true) {
        self.isCalled = isCalled
    }

    func call(_ called: Bool) {
        guard called != isCalled else { return }
        withAnimation(.smooth(duration: 0.25)) { isCalled = called }
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
