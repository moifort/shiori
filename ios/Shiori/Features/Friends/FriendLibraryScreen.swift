import SwiftUI

/// A friend's whole library, connected: loads a page per view and filter,
/// takes a book onto the reader's pile, opens a book as a sheet, and hands the
/// rest to `FriendLibraryPage`.
struct FriendLibraryScreen: View {
    let friendId: String
    let friendName: String
    /// The reader's own library, previewed: every book is theirs already.
    var isPreview = false
    var client: FriendsClient = .live

    @State private var model = FriendShelfListModel<FriendBook>(ownedFlag: \.inLibrary)
    @State private var mode: LibraryMode = .all
    @State private var status: ReadingStatus?
    @State private var openBook: FriendBook?

    var body: some View {
        FriendLibraryPage(
            friendName: friendName,
            books: model.rows,
            mode: $mode,
            status: $status,
            isWaiting: model.loadedQuery != query && model.errorMessage == nil,
            loadFailed: model.loadedQuery != query || model.rows.isEmpty ? model.errorMessage : nil,
            hasMore: model.hasMore,
            loadMoreFailed: model.loadMoreFailed,
            adding: model.adding,
            isPreview: isPreview
        ) { action in
            switch action {
            case let .openBook(book): openBook = book
            case let .take(book, format):
                await model.take(book.id) {
                    try await client.addBook(friendId, book.id, .toRead, format)
                }
            case .loadMore: await model.loadMore(fetch: fetch)
            case .refresh: await model.load(query: query, fetch: fetch)
            }
        }
        .task(id: query) { await model.load(query: query, fetch: fetch) }
        // A sheet, as a book opens from the reader's own library: its own
        // stack, so the saga pushes inside it.
        .sheet(item: $openBook) { book in
            NavigationStack {
                FriendBookScreen(
                    friendId: friendId,
                    bookId: book.id,
                    friendName: friendName,
                    onAdded: { model.markOwned(book.id) }
                )
            }
        }
        .alert(
            "Ajout impossible",
            isPresented: .init(get: { model.addFailed != nil }, set: { if !$0 { model.addFailed = nil } })
        ) {
            Button("OK", role: .cancel) { model.addFailed = nil }
        } message: {
            Text(model.addFailed ?? "")
        }
    }

    private var query: String { "\(mode.rawValue)-\(status?.rawValue ?? "all")" }

    private var fetch: FriendShelfListModel<FriendBook>.Fetch {
        let (client, friendId, status, loved) = (client, friendId, status, mode == .favorites)
        return { after in
            let page = try await client.libraryPage(friendId, status, loved, after)
            return (page.books, page.hasMore)
        }
    }
}

#Preview {
    NavigationStack {
        FriendLibraryScreen(friendId: "camille", friendName: "Camille", client: .preview)
    }
}
