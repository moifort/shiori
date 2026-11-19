import SwiftUI

/// The book the full-screen player's three dots asked for, pushed on the tab
/// in front once the player has closed: the page opens with the usual Back
/// button, the title still playing in the capsule over the tab bar, rather
/// than in a sheet of its own.
@MainActor @Observable
final class PlayerBookRoute {
    /// The book waiting to be pushed, and the tab that pushes it.
    private(set) var request: Request?

    struct Request: Equatable {
        let bookID: String
        let tab: TabSelection
        /// Two asks for the same book are two pushes.
        let id = UUID()
    }

    func open(_ bookID: String, on tab: TabSelection) {
        request = Request(bookID: bookID, tab: tab)
    }

    /// The request for `tab`, handed out once.
    fileprivate func take(for tab: TabSelection) -> String? {
        guard let request, request.tab == tab else { return nil }
        self.request = nil
        return request.bookID
    }
}

extension EnvironmentValues {
    /// Set once for the whole app by `ContentView`; nil in previews.
    @Entry var playerBookRoute: PlayerBookRoute?
    /// The tab a screen sits in, set on each tab's content.
    @Entry var hostTab: TabSelection?
}

extension View {
    /// Pushes, on the enclosing stack, the book the player asked for while
    /// this tab is in front. Put on the root page of each content tab.
    func pushesPlayerBook() -> some View {
        modifier(PlayerBookPush())
    }
}

private struct PlayerBookPush: ViewModifier {
    @Environment(\.playerBookRoute) private var route
    @Environment(\.hostTab) private var tab
    @State private var book: OpenedBook?

    func body(content: Content) -> some View {
        content
            .pushesDetail(item: $book) { BookScreen(bookId: $0.id) }
            .onChange(of: route?.request, initial: true) {
                guard let tab, let bookID = route?.take(for: tab) else { return }
                book = OpenedBook(id: bookID)
            }
    }

    private struct OpenedBook: Identifiable {
        let id: String
    }
}
