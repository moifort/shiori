import SwiftUI

/// Everything a friend's library page can ask for.
enum FriendLibraryAction {
    case openBook(FriendBook)
    /// The "+" of a row: onto the reader's pile, in the format they take it in.
    case take(FriendBook, as: BookFormat)
    case loadMore
    case refresh
}

/// A friend's whole library — or the reader's own, previewed — drawn as the
/// reader's Library tab draws theirs: newest first on the day each book was
/// shelved, cut into months, or the favourites — hearts, then five stars down
/// to one — the two views and a status filter in the corner. No mosaic: the
/// covers are the friend's page's own strips. The dropped books show only
/// through their filter, and a book marked "do not share" never.
///
/// Each row opens the book on the friend's read-only page and carries the "+"
/// that puts it on the reader's pile, greyed out on a book they own.
struct FriendLibraryPage: View {
    let friendName: String
    let books: [FriendBook]
    @Binding var mode: LibraryMode
    @Binding var status: ReadingStatus?
    /// The rows on screen answer another view or filter, or none yet.
    let isWaiting: Bool
    /// The page could not be read, with nothing of this view to show.
    let loadFailed: String?
    let hasMore: Bool
    let loadMoreFailed: Bool
    /// The rows whose "+" is turning.
    let adding: Set<String>
    /// The reader's own library, previewed: every book is theirs already.
    let isPreview: Bool
    let onAction: (FriendLibraryAction) async -> Void

    var body: some View {
        Group {
            if isWaiting {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let loadFailed {
                EmptyState.failure("Bibliothèque indisponible", message: loadFailed) {
                    await onAction(.refresh)
                }
            } else if books.isEmpty {
                Text(
                    status == nil && mode == .all
                        ? "Aucun livre n'a été ajouté à cette bibliothèque."
                        : "Aucun livre ne correspond."
                )
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
        .toolbar { toolbar }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup {
            ForEach(LibraryMode.allCases) { item in
                Button {
                    mode = item
                } label: {
                    Label(item.label, systemImage: item.icon)
                }
                .labelStyle(.iconOnly)
                .tint(mode == item ? .accentColor : .primary)
                .accessibilityIdentifier("friend-library-mode-\(item.rawValue)")
            }
        }
        ToolbarSpacer(.fixed)
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
                ShelfFilterLabel(
                    symbol: status?.symbol ?? "tray.full",
                    title: status?.shelfTitle ?? String(localized: "Tous")
                )
            }
            .accessibilityIdentifier("friend-library-filter")
        }
    }

    private var list: some View {
        List {
            ForEach(sections) { section in
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
                    onLoadMore: { await onAction(.loadMore) }
                )
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await onAction(.refresh) }
    }

    /// Cut into months — or, under the favourites, into the hearts and then
    /// each count of stars, as the server ranked them.
    private var sections: [ListSection<FriendBook>] {
        mode == .favorites
            ? ListSection.byRank(books, rank: \.book.lovedRank)
            : ListSection.byMonth(books, on: \.book.shelvedAt)
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
            .onTapGesture { Task { await onAction(.openBook(entry)) } }
            TakeButton(
                owned: entry.inLibrary || isPreview,
                isAdding: adding.contains(entry.id),
                format: book.format
            ) { format in
                await onAction(.take(entry, as: format))
            }
        }
        .edgeToEdgeSeparator()
        .accessibilityIdentifier("friend-library-row")
    }
}

#Preview("Library") {
    @Previewable @State var mode = LibraryMode.all
    @Previewable @State var status: ReadingStatus?
    NavigationStack {
        FriendLibraryPage(
            friendName: "Camille",
            books: FriendProfile.preview.favorites + FriendProfile.preview.reading,
            mode: $mode, status: $status,
            isWaiting: false, loadFailed: nil, hasMore: true, loadMoreFailed: false,
            adding: [], isPreview: false
        ) { _ in }
    }
}

#Preview("Nothing matches") {
    NavigationStack {
        FriendLibraryPage(
            friendName: "Camille", books: [], mode: .constant(.all), status: .constant(.dropped),
            isWaiting: false, loadFailed: nil, hasMore: false, loadMoreFailed: false,
            adding: [], isPreview: false
        ) { _ in }
    }
}
