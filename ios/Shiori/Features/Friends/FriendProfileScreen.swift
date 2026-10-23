import SwiftUI

/// One friend's shelf, connected: loads it, pushes a book and the whole
/// library by its link, and hands the rest to `FriendProfilePage`.
///
/// The reader's own shelf opens on this very screen, as a preview: drawn from
/// the shelf they already hold, every "+" greyed out since every book is
/// theirs, and each cover opening the page a friend would open.
struct FriendProfileScreen: View {
    @State private var viewModel: FriendProfileViewModel
    @State private var openBook: FriendBook?

    init(friend: Friend, client: FriendsClient = .live) {
        _viewModel = State(initialValue: FriendProfileViewModel(friend: friend, client: client))
    }

    /// The reader's own page as their friends see it.
    init(preview shelf: FriendProfile) {
        _viewModel = State(initialValue: FriendProfileViewModel(preview: shelf))
    }

    var body: some View {
        let friend = viewModel.friend
        FriendProfilePage(
            friend: friend,
            profile: viewModel.profile,
            isPreview: viewModel.isPreview,
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage
        ) { action in
            switch action {
            case let .openBook(book): openBook = book
            case .refresh: await viewModel.load()
            }
        }
        .task { await viewModel.load() }
        .navigationDestination(for: FriendProfileDestination.self) { _ in
            FriendShelfScreen(friendId: friend.userId, friendName: friend.displayName, isPreview: viewModel.isPreview)
                .closesAsPushed()
        }
        // Pushed, as a book opens from the reader's own library; its saga
        // pushes after it.
        .pushesDetail(item: $openBook) { book in
            FriendBookScreen(
                friendId: friend.userId,
                bookId: book.id,
                friendName: friend.displayName,
                onAdded: { viewModel.markOwned(book.id) }
            )
        }
    }
}

#Preview {
    NavigationStack {
        FriendProfileScreen(friend: Friend.previews[0], client: .preview)
    }
}
