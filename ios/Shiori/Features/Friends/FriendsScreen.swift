import SwiftUI

/// The Amis tab, connected: loads the friends and the rails for the friends
/// picked, opens a book, one friend's library and series, the invitation, and
/// hands the rest to `FriendsPage`.
///
/// The tab opens on what it last showed for the same pick, brought up to date
/// silently underneath.
struct FriendsScreen: View {
    @State private var viewModel: FriendsViewModel
    @State private var openedBook: OpenedBook?
    @State private var route: FriendsRoute?
    /// A friend another tab asked for: the page narrowed to them alone, back
    /// at its top.
    @Binding var friendRequest: String?
    /// The friend an invitation just joined: welcomed once they are in the
    /// row, then let go.
    @Binding var welcomedFriend: String?

    init(
        client: FriendsClient = .live,
        friendRequest: Binding<String?> = .constant(nil),
        welcomedFriend: Binding<String?> = .constant(nil)
    ) {
        _viewModel = State(initialValue: FriendsViewModel(client: client))
        _friendRequest = friendRequest
        _welcomedFriend = welcomedFriend
    }

    var body: some View {
        // A cover is pushed over the tab on a phone, and set beside it on an
        // unfolded iPhone Duo.
        DetailSplit(item: $openedBook) {
            FriendsPage(
                friends: viewModel.friends,
                selected: viewModel.picked,
                shelf: viewModel.shelf,
                soleFriend: viewModel.soleFriend,
                myShelf: viewModel.myShelf,
                hasNoFriend: viewModel.hasNoFriend,
                isWaiting: viewModel.isEmpty && !viewModel.loaded && viewModel.loadFailed == nil,
                loadFailed: viewModel.isEmpty ? viewModel.loadFailed : nil,
                isInviting: viewModel.isInviting,
                welcomed: welcomed
            ) { action in
                switch action {
                case let .toggle(friendId): await viewModel.toggle(friendId)
                case let .openBook(entry):
                    openedBook = OpenedBook(
                        bookId: entry.book.id,
                        friendId: entry.friendId,
                        friendName: entry.friendName ?? String(localized: "Un lecteur")
                    )
                case let .openMyBook(book): openedBook = OpenedBook(bookId: book.id, friendId: nil, friendName: "")
                case let .openLibrary(friend): route = .library(friend.userId, friend.displayName)
                case let .openSeries(friend): route = .series(friend.userId, friend.displayName)
                case .invite: await viewModel.invite()
                case let .remove(friendId): await viewModel.remove(friendId)
                case .refresh: await viewModel.load()
                }
            }
            .navigationDestination(item: $route) { route in
                switch route {
                case let .library(friendId, name):
                    FriendLibraryScreen(friendId: friendId, friendName: name).closesAsPushed()
                case let .series(friendId, name):
                    FriendSeriesListScreen(friendId: friendId, friendName: name).closesAsPushed()
                }
            }
        } detail: { opened in
            if let friendId = opened.friendId {
                FriendBookScreen(friendId: friendId, bookId: opened.bookId, friendName: opened.friendName)
            } else {
                BookScreen(bookId: opened.bookId)
            }
        }
        .task { await viewModel.loadOnAppear() }
        .onChange(of: friendRequest, initial: true) { _, friendId in
            guard let friendId else { return }
            friendRequest = nil
            route = nil
            openedBook = nil
            Task { await viewModel.show(only: friendId) }
        }
        // A friend added or a book taken changes what the rails say: asked
        // again on the next look.
        .onReceive(NotificationCenter.default.publisher(for: .shioriDataDidChange)) { _ in
            Task { await viewModel.load() }
        }
        .sharesInvitation($viewModel.invitation)
        // The welcome plays once the friend is in the row, which the reload
        // the acceptance asked for brings, and stops after the burst.
        .task(id: welcomed) {
            guard welcomed != nil else { return }
            try? await Task.sleep(for: .seconds(3))
            welcomedFriend = nil
        }
        .alert(
            "Une erreur est survenue",
            isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    /// The friend to welcome, once they are among the friends shown.
    private var welcomed: String? {
        guard let welcomedFriend, viewModel.friends.contains(where: { $0.userId == welcomedFriend }) else { return nil }
        return welcomedFriend
    }
}

/// What a row of the tab pushes: one friend's library or series.
private enum FriendsRoute: Hashable, Identifiable {
    case library(String, String)
    case series(String, String)

    var id: Self { self }
}

/// A book opened from a cover: a friend's, or the reader's own when the
/// friend is nil.
private struct OpenedBook: Identifiable, Hashable {
    let bookId: String
    let friendId: String?
    let friendName: String

    var id: String { "\(friendId ?? "me")-\(bookId)" }
}

#Preview {
    FriendsScreen(client: .preview)
}
