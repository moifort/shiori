import SwiftUI

/// One friend's shelf, summed up as Découvrir sums up its books: the figures,
/// then one card — their whole library behind a line that opens it, Books and
/// Series switched by the Library tab's capsule; their hearts, newest first;
/// their pile, the last added first, each over a strip of its covers.
///
/// Read-only as far as the friend's library goes. A cover opens the friend's
/// book on a page with no control that writes to it, which offers instead to
/// add the book to the reader's pile.
///
/// The page opens on the shelf it showed last time, kept on disk per friend,
/// and the server's answer slides into place underneath.
///
/// Books they marked "do not share" are absent, and no reading note is drawn:
/// a friend sees a shelf, not a diary.
///
/// The reader's own shelf opens on this very page, as a preview: drawn from
/// the shelf they already hold, every "+" greyed out since every book is
/// theirs, and each cover opening the page a friend would open.
struct FriendProfileView: View {
    let friend: Friend
    private let isPreview: Bool

    @State private var profile: FriendProfile?
    @State private var isLoading: Bool
    @State private var errorMessage: String?
    @State private var openBook: FriendBook?

    /// The friend's shelf as it was last shown, so the page opens on it while
    /// the server is asked again underneath. Nil on the preview, which draws
    /// the reader's own shelf already in hand.
    private let cache: SnapshotCache<FriendProfile>?

    init(friend: Friend) {
        self.friend = friend
        isPreview = false
        // Bump the version whenever `FriendProfile` changes shape.
        let cache = SnapshotCache<FriendProfile>("friend-\(friend.userId)", version: 1)
        self.cache = cache
        _profile = State(initialValue: cache.read())
        _isLoading = State(initialValue: true)
    }

    /// The reader's own page as their friends see it.
    init(preview shelf: FriendProfile) {
        friend = Friend(seenByFriends: shelf)
        isPreview = true
        cache = nil
        _profile = State(initialValue: shelf)
        _isLoading = State(initialValue: false)
    }

    var body: some View {
        Group {
            if isLoading && profile == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let profile, !profile.isEmpty {
                shelves(profile)
            } else if let errorMessage {
                EmptyStateView.failure("Bibliothèque indisponible", message: errorMessage) { await load() }
            } else {
                Text("Aucun livre n'a été ajouté à cette bibliothèque.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(profile?.displayName ?? friend.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task { if !isPreview { await load() } }
        .toolbar { if isPreview { shareFavorites } }
        // A sheet, as a book opens from the reader's own library: its own
        // stack, so the saga pushes inside it.
        .sheet(item: $openBook) { book in
            NavigationStack {
                FriendBookView(
                    friendId: friend.userId,
                    bookId: book.id,
                    friendName: friend.displayName,
                    onAdded: { markOwned(book.id) }
                )
            }
        }
    }

    private func shelves(_ profile: FriendProfile) -> some View {
        List {
            Section {
                HStack(spacing: 8) {
                    tile(friend.favoriteCount, "Favoris", systemImage: "heart.fill", tint: .red)
                    tile(friend.readingCount, "En cours", systemImage: "book.fill", tint: ReadingStatus.reading.tint)
                    tile(friend.toReadCount, "À lire", systemImage: "bookmark.fill", tint: ReadingStatus.toRead.tint)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            // The shelf at a glance, as Découvrir sums up its books: the whole
            // library behind one line, then the hearts and the pile, each over
            // a strip of its covers, a tap opening the book.
            Section {
                NavigationLink {
                    FriendShelfView(
                        friendId: friend.userId,
                        friendName: friend.displayName,
                        isPreview: isPreview
                    )
                } label: {
                    DiscoverSummaryRow(
                        title: isPreview ? "Ma bibliothèque" : "Sa bibliothèque",
                        systemImage: "books.vertical.fill",
                        tint: .accentColor,
                        line: libraryLine(profile)
                    )
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 16))
                .accessibilityIdentifier("friend-see-library")
                if let latest = profile.favorites.first {
                    DiscoverSummaryRow(
                        title: isPreview ? "Mes favoris" : "Ses favoris",
                        systemImage: "heart.fill",
                        tint: .red,
                        line: String(localized: "Dernier : \(latest.book.title)")
                    ) {
                        covers(profile.favorites)
                    }
                    .accessibilityIdentifier("friend-favorites")
                }
                if let latest = profile.pile.first {
                    DiscoverSummaryRow(
                        title: isPreview ? "Ma pile à lire" : "Sa pile à lire",
                        systemImage: "bookmark.fill",
                        tint: ReadingStatus.toRead.tint,
                        line: String(localized: "Dernier ajout : \(latest.book.title)")
                    ) {
                        covers(profile.pile)
                    }
                    .accessibilityIdentifier("friend-pile")
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { if !isPreview { await load() } }
    }

    /// The preview keeps what the favourites list used to offer: the whole
    /// list as text, for a mail, a message, or the clipboard.
    @ToolbarContentBuilder
    private var shareFavorites: some ToolbarContent {
        if let profile, !(profile.favoriteSagas.isEmpty && profile.favorites.isEmpty) {
            let text = FavoritesSharing.text(
                sagas: profile.favoriteSagas,
                books: profile.favorites.map(\.book)
            )
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    FavoritesShareItems(text: text)
                } label: {
                    Label("Partager mes favoris", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("my-shelf-share-favorites")
            }
        }
    }

    private func tile(_ count: Int, _ label: LocalizedStringKey, systemImage: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Image(systemName: systemImage).font(.subheadline).foregroundStyle(tint)
            Text(verbatim: "\(count)").font(.title3.weight(.semibold))
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
    }

    /// "12 séries · 80 livres", the sagas left out when there are none.
    private func libraryLine(_ profile: FriendProfile) -> String {
        let books = String(AttributedString(localized: "^[\(profile.bookCount) livre](inflect: true)").characters)
        guard !profile.sagas.isEmpty else { return books }
        let sagas = String(AttributedString(localized: "^[\(profile.sagas.count) série](inflect: true)").characters)
        return "\(sagas) · \(books)"
    }

    /// The covers of a summary line, newest first as the server sends them,
    /// each opening the book.
    private func covers(_ books: [FriendBook]) -> some View {
        ForEach(books) { entry in
            Button { openBook = entry } label: {
                BookCover(
                    book: entry.book,
                    width: CoverTile.summaryWidth,
                    formatBadgeSize: CoverTile.formatBadgeSize
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(entry.book.title)
            .accessibilityIdentifier("friend-book-cover")
        }
    }

    /// The shelf last shown stays while the server is asked again; its
    /// answer slides into place. A refresh that fails over a shelf already on
    /// screen says nothing — a pull tries again — and only an empty page shows
    /// the failure.
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await FriendsAPI.profile(userId: friend.userId)
            withAnimation(profile == nil ? nil : .smooth) { profile = fetched }
            errorMessage = nil
            write()
        } catch {
            guard !isCancellation(error) else { return }
            let message = reportError(error)
            if profile == nil { errorMessage = message }
        }
    }

    private func write() {
        guard let cache, let profile else { return }
        Task.detached { cache.write(profile) }
    }

    /// The book is the reader's now: every shelf of this screen says so,
    /// without asking the server for the whole profile again.
    private func markOwned(_ bookId: String) {
        guard var profile else { return }
        for index in profile.reading.indices where profile.reading[index].id == bookId {
            profile.reading[index].inLibrary = true
        }
        for index in profile.pile.indices where profile.pile[index].id == bookId {
            profile.pile[index].inLibrary = true
        }
        for index in profile.favorites.indices where profile.favorites[index].id == bookId {
            profile.favorites[index].inLibrary = true
        }
        if profile.lastFinished?.id == bookId {
            profile.lastFinished?.inLibrary = true
        }
        if profile.lastDropped?.id == bookId {
            profile.lastDropped?.inLibrary = true
        }
        if profile.lastAdded?.id == bookId {
            profile.lastAdded?.inLibrary = true
        }
        self.profile = profile
        write()
    }
}

extension FriendProfile {
    static let preview: FriendProfile = {
        let hunter = FriendBook(
            book: Book(
                id: "hunter", title: "Primal Hunter", authors: ["Zogarth"], format: .audiobook,
                listeningProgress: 32,
                series: SeriesMembership(id: "ph", name: "Primal Hunter", volume: 6, kind: .main),
                status: .reading
            ),
            inLibrary: true,
            lastActivityAt: .now.addingTimeInterval(-3600)
        )
        let wind = FriendBook(
            book: Book(
                id: "wind", title: "Le Nom du vent", authors: ["Patrick Rothfuss"], status: .read,
                favorite: true, finishedAt: .now.addingTimeInterval(-86400 * 4)
            ),
            inLibrary: false,
            favoritedAt: .now.addingTimeInterval(-86400 * 20)
        )
        let dune = FriendBook(
            book: Book(id: "dune", title: "Dune", authors: ["Frank Herbert"], status: .read, favorite: true),
            inLibrary: false,
            favoritedAt: .now.addingTimeInterval(-86400 * 9)
        )
        let ulysse = FriendBook(
            book: Book(id: "ulysse", title: "Ulysse", authors: ["James Joyce"], status: .dropped),
            inLibrary: false,
            lastActivityAt: .now.addingTimeInterval(-86400 * 2)
        )
        var silo = FriendBook(
            book: Book(id: "silo", title: "Silo", authors: ["Hugh Howey"], status: .toRead),
            inLibrary: false
        )
        silo.book.addedAt = .now.addingTimeInterval(-86400)
        let reading = [
            ("piranesi", "Piranesi", "Susanna Clarke"),
            ("lune", "La Lune est une maîtresse cruelle", "Robert A. Heinlein"),
            ("hypérion", "Hypérion", "Dan Simmons"),
        ].map { id, title, author in
            FriendBook(book: Book(id: id, title: title, authors: [author], status: .reading), inLibrary: false)
        }
        let favorites = [
            ("fondation", "Fondation", "Isaac Asimov"),
            ("ubik", "Ubik", "Philip K. Dick"),
        ].map { id, title, author in
            FriendBook(
                book: Book(id: id, title: title, authors: [author], status: .read, favorite: true),
                inLibrary: false
            )
        }
        return FriendProfile(
            userId: "camille",
            firstName: "Camille",
            reading: [hunter] + reading,
            pile: [silo] + reading.prefix(2),
            favorites: [dune, wind] + favorites,
            sagas: [],
            lastFinished: wind,
            lastDropped: ulysse,
            lastAdded: silo,
            bookCount: 9,
            readThisYear: 2
        )
    }()
}

#Preview("Shelf") {
    NavigationStack {
        FriendProfileView(preview: .preview)
    }
}
