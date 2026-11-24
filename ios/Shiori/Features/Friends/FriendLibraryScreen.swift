import SwiftUI

/// A friend's "Livres", connected: the reader's own "Livres" — the mosaic cut
/// into months, the status menu, the format pills — over the friend's books.
/// A cover opens the friend's read-only page; the long press puts the book on
/// the reader's pile, or leads to its series or its author.
struct FriendLibraryScreen: View {
    let friendId: String
    let friendName: String
    var client: FriendsClient = .live

    @State private var model = FriendShelfListModel<FriendBook>(ownedFlag: \.inLibrary)
    @State private var status: ReadingStatus?
    @State private var format: BookFormat?
    /// The formats the friend holds, kept from the first page shown without a
    /// format chosen, and grown as more pages come: the pills.
    @State private var formats: [BookFormat] = []
    @State private var openBook: FriendBook?
    @State private var openSeries: SeriesDestinationID?
    @State private var openAuthor: AuthorDestination?

    var body: some View {
        BookMosaicPage(
            sections: model.loadedQuery == query ? ListSection.byMonth(books, on: \.shelvedAt) : [],
            ownedByReader: { book in model.rows.first { $0.id == book.id }?.inLibrary == true },
            formats: formats,
            selectedFormat: format,
            selectedStatus: status,
            isLoading: model.loadedQuery != query && model.errorMessage == nil,
            errorMessage: model.loadedQuery != query || model.rows.isEmpty ? model.errorMessage : nil,
            hasMore: model.hasMore,
            loadMoreFailed: model.loadMoreFailed,
            onAction: handle
        )
        .scrollAwayBar(BookShelf.all.title)
        .task(id: query) {
            await model.load(query: query, fetch: fetch)
            noteFormats()
        }
        // Pushed, as a book opens from the reader's own library.
        .pushesDetail(item: $openBook) { book in
            FriendBookScreen(
                friendId: friendId,
                bookId: book.id,
                friendName: friendName,
                onAdded: { model.markOwned(book.id) }
            )
        }
        // The saga as a friend's saga opens: where the friend stands on it.
        .pushesDetail(item: $openSeries) { series in
            SeriesScreen(seriesId: series.id, friend: SeriesFriend(id: friendId, name: friendName))
        }
        .pushesDetail(item: $openAuthor) { AuthorScreen(key: $0.key, name: $0.name) }
        .alert(
            "Ajout impossible",
            isPresented: .init(get: { model.addFailed != nil }, set: { if !$0 { model.addFailed = nil } })
        ) {
            Button("OK", role: .cancel) { model.addFailed = nil }
        } message: {
            Text(model.addFailed ?? "")
        }
    }

    private var books: [Book] { model.rows.map(\.book) }

    private func handle(_ action: BookShelfAction) {
        switch action {
        case let .openBook(book): openBook = model.rows.first { $0.id == book.id }
        case let .selectStatus(status): self.status = status
        case let .selectFormat(format): self.format = format
        case let .menu(book, .take):
            Task {
                await model.take(book.id) {
                    try await client.addBook(friendId, book.id, .toRead, book.format)
                }
            }
        case let .menu(_, .openSeries(id)): openSeries = SeriesDestinationID(id: id)
        case let .menu(_, .openAuthor(key, name)): openAuthor = AuthorDestination(key: key, name: name)
        case let .reached(id):
            guard model.hasMore, let index = model.rows.firstIndex(where: { $0.id == id }),
                  model.rows.count - index <= 15 else { return }
            Task {
                await model.loadMore(fetch: fetch)
                noteFormats()
            }
        case .loadMore:
            Task {
                await model.loadMore(fetch: fetch)
                noteFormats()
            }
        case .refresh: Task { await model.load(query: query, fetch: fetch) }
        case .menu, .openSeries, .selectGenre, .share: break
        }
    }

    /// The pills offer every format the friend's books shown so far hold,
    /// as the reader's own "Livres" does; a format chosen keeps them as they are.
    private func noteFormats() {
        guard format == nil else { return }
        let held = Set(model.rows.map(\.book.format))
        formats = BookFormat.allCases.filter { held.contains($0) || formats.contains($0) }
    }

    private var query: String { "\(status?.rawValue ?? "all")-\(format?.rawValue ?? "all")" }

    private var fetch: FriendShelfListModel<FriendBook>.Fetch {
        let (client, friendId, status, format) = (client, friendId, status, format)
        return { after in
            let page = try await client.libraryPage(friendId, status, format, after)
            return (page.books, page.hasMore)
        }
    }
}

#Preview {
    NavigationStack {
        FriendLibraryScreen(friendId: "camille", friendName: "Camille", client: .preview)
    }
}
