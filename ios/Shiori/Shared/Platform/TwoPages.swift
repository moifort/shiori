import SwiftUI

/// Two pages on an iPhone Duo's inner screen, one each side of the crease, and
/// the same content as one page everywhere else.
///
/// - Laid flat: side by side, parted by a hairline on the fold's line.
/// - Partly folded like a book: left and right of the crease, nothing on it.
/// - Partly folded like a laptop: the first page above the crease, the second
///   below, as the Camera app keeps the viewfinder up and the controls down.
/// - A phone, the outer screen, or a view the fold does not cross: `single`.
///
/// Whether two pages are shown goes up as `TwoPagesShownKey`, so a screen can
/// move a task onto the second page rather than cover the spread with a sheet.
struct TwoPages<First: View, Second: View, Single: View>: View {
    @ViewBuilder let first: () -> First
    @ViewBuilder let second: () -> Second
    @ViewBuilder let single: () -> Single

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        GeometryReader { proxy in
            let posture = proxy.foldPosture(isRegular: sizeClass == .regular)
            if let pages = posture.pages(in: proxy.size) {
                ZStack {
                    first()
                        .frame(width: pages.first.width, height: pages.first.height)
                        .position(x: pages.first.midX, y: pages.first.midY)
                    second()
                        .frame(width: pages.second.width, height: pages.second.height)
                        .position(x: pages.second.midX, y: pages.second.midY)
                    if case let .flat(line) = posture {
                        Rectangle()
                            .fill(.separator)
                            .frame(width: 1 / 3, height: proxy.size.height)
                            .position(x: line, y: proxy.size.height / 2)
                            .allowsHitTesting(false)
                    }
                }
                .environment(\.foldPosture, posture)
                .preference(key: TwoPagesShownKey.self, value: true)
            } else {
                single()
                    .preference(key: TwoPagesShownKey.self, value: false)
            }
        }
    }
}

extension TwoPages where Single == VStack<TupleView<(First, Second)>> {
    /// Two pages, or the first above the second on one.
    init(@ViewBuilder first: @escaping () -> First, @ViewBuilder second: @escaping () -> Second) {
        self.first = first
        self.second = second
        self.single = { VStack(spacing: 0) { first(); second() } }
    }
}

/// Whether a `TwoPages` below laid its content out as two pages.
struct TwoPagesShownKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

extension EnvironmentValues {
    /// The posture the enclosing `TwoPages` laid its pages out for: a page can
    /// tell a book from a laptop, and draw its controls where the hand is.
    @Entry var foldPosture: FoldPosture = .single
}
