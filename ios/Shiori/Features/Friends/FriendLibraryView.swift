import SwiftUI

/// A friend's whole library — or the reader's own, previewed — drawn as the
/// reader's Library tab draws theirs: newest first on the day each book was
/// shelved, cut into months, a status filter in the corner, the next page
/// asked for as the list runs out. The dropped books show only through their
/// filter, and a book marked "do not share" never.
///
/// Each row opens the book on the friend's read-only page and carries the "+"
/// that puts it on the reader's pile, greyed out on a book they own.
struct FriendLibraryView: View {
    let friendId: String
    let friendName: String
    /// The reader's own library, previewed: every book is theirs already.
    var isPreview = false

    @State private var books: [FriendBook] = []
    @State private var status: ReadingStatus?
    @State private var hasMore = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var loadMoreFailed = false
    @State private var openBook: FriendBook?
    @State private var adding: Set<String> = []
    @State private var addFailed: String?

    var body: some View {
        Group {
            if isLoading && books.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage, books.isEmpty {
                EmptyStateView.failure("Bibliothèque indisponible", message: errorMessage) { await load() }
            } else if books.isEmpty {
                Text(status == nil ? "Aucun livre n'a été ajouté à cette bibliothèque." : "Aucun livre n'a ce statut.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                list
            }
        }
        .navigationTitle("Bibliothèque")
        .navigationSubtitle(friendName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Statut", selection: $status) {
                        Label("Tous", systemImage: "tray.full").tag(ReadingStatus?.none)
                        // In the order a book lives through them, as the Library tab.
                        ForEach([ReadingStatus.reading, .toRead, .read, .dropped]) { status in
                            Label(status.shelfTitle, systemImage: status.symbol)
                                .tag(ReadingStatus?.some(status))
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .symbolVariant(status != nil ? .fill : .none)
                }
                .accessibilityIdentifier("friend-library-filter")
            }
        }
        .task(id: status) { await load() }
        .navigationDestination(item: $openBook) { book in
            FriendBookView(
                friendId: friendId,
                bookId: book.id,
                friendName: friendName,
                onAdded: { markOwned(book.id) }
            )
        }
        .alert(
            "Ajout impossible",
            isPresented: .init(get: { addFailed != nil }, set: { if !$0 { addFailed = nil } })
        ) {
            Button("OK", role: .cancel) { addFailed = nil }
        } message: {
            Text(addFailed ?? "")
        }
    }

    private var list: some View {
        List {
            ForEach(MonthSection.cut(books, on: { $0.book.shelvedAt })) { section in
                Section(section.title) {
                    ForEach(section.rows) { entry in
                        row(entry)
                    }
                }
            }
            if hasMore {
                LoadMoreRow(
                    failed: loadMoreFailed,
                    loadingLabel: "Chargement de la suite",
                    onLoadMore: loadMore
                )
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await load() }
    }

    private func row(_ entry: FriendBook) -> some View {
        let book = entry.book
        // The "+" on the first line, as on every row of a friend's shelf.
        return HStack(alignment: .top, spacing: 8) {
            BookRow(
                title: book.title,
                authorLine: book.authorLine,
                cover: book,
                status: book.status,
                rating: book.rating,
                series: book.series,
                // Rows say their own status, unless the filter already says which.
                statusTag: status == nil ? book.status : nil,
                genre: book.genre,
                subgenre: book.subgenres.first,
                language: book.language,
                isFavorite: book.favorite
            )
            .contentShape(.rect)
            .onTapGesture { openBook = entry }
            TakeButton(owned: entry.inLibrary || isPreview, isAdding: adding.contains(entry.id)) {
                await add(entry)
            }
        }
        .edgeToEdgeSeparator()
        .accessibilityIdentifier("friend-library-row")
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        loadMoreFailed = false
        do {
            let page = try await FriendsAPI.libraryPage(friendId: friendId, status: status, after: nil)
            books = page.books
            hasMore = page.hasMore
        } catch {
            errorMessage = reportError(error)
        }
        isLoading = false
    }

    private func loadMore() async {
        loadMoreFailed = false
        do {
            let page = try await FriendsAPI.libraryPage(friendId: friendId, status: status, after: books.last?.id)
            books.append(contentsOf: page.books.filter { new in !books.contains { $0.id == new.id } })
            hasMore = page.hasMore
        } catch {
            _ = reportError(error)
            loadMoreFailed = true
        }
    }

    private func add(_ entry: FriendBook) async {
        adding.insert(entry.id)
        defer { adding.remove(entry.id) }
        do {
            try await FriendsAPI.addBook(friendId: friendId, bookId: entry.id, status: .toRead)
            markOwned(entry.id)
        } catch {
            addFailed = reportError(error)
        }
    }

    private func markOwned(_ bookId: String) {
        for index in books.indices where books[index].id == bookId {
            books[index].inLibrary = true
        }
    }
}
