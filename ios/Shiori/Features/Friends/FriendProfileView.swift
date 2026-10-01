import SwiftUI

/// One friend's shelf: what they are reading, their pile, what they keep close
/// and the sagas they are working through — and the place to take any of it
/// onto the reader's own shelf.
///
/// Read-only as far as the friend's library goes. The books in progress and
/// the hearted ones are bare covers side by side; a tap opens the friend's
/// book on a page with no control that writes to it, which offers instead to
/// add the book to the reader's pile. A hearted saga keeps its "+" on its row.
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
    @State private var addFailed: String?
    /// The sagas being added from their row, each showing its own spinner.
    @State private var addingSagas: Set<String> = []

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
        .alert(
            "Ajout impossible",
            isPresented: .init(get: { addFailed != nil }, set: { if !$0 { addFailed = nil } })
        ) {
            Button("OK", role: .cancel) { addFailed = nil }
        } message: {
            Text(addFailed ?? "")
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
            // What moved lately, under the figures, so a friend coming back
            // finds what changed rather than the same lists: the last book in
            // progress, finished and hearted, as covers side by side. A tap
            // opens the book.
            let recent = profile.recentActivity()
            if !recent.isEmpty {
                Section("Activités récentes") {
                    RecentActivityStrip(activities: recent) { openBook = $0 }
                }
            }
            // Every book in progress, the one touched last first, as bare
            // covers: the one the recent activity leads with included. A
            // section with nothing in it is not drawn at all.
            if !profile.reading.isEmpty {
                Section("En cours") {
                    FriendCoverStrip(books: profile.reading) { openBook = $0 }
                }
            }
            // A hearted saga stands for its volumes: the books below it are
            // the hearts it does not already cover.
            if !profile.favoriteSagas.isEmpty {
                Section {
                    ForEach(profile.favoriteSagasByShelf) { saga in
                        SagaRow(saga: saga, showsCovers: true) {
                            TakeButton(
                                owned: saga.inLibrary || isPreview || saga.volumes.isEmpty,
                                isAdding: addingSagas.contains(saga.id),
                                format: saga.takenFormat,
                                addLabel: "Ajouter la série à mes séries",
                                ownedLabel: "Série déjà dans votre bibliothèque"
                            ) { format in
                                await add(saga, as: format)
                            }
                        }
                        .edgeToEdgeSeparator()
                    }
                } header: {
                    hearted("Séries")
                }
            }
            if !profile.favorites.isEmpty {
                Section {
                    FriendCoverStrip(books: profile.favoritesByShelf) { openBook = $0 }
                } header: {
                    hearted("Livres")
                }
            }
            // The rest of the shelf is a list of its own, drawn as the
            // reader's own Series and Library tabs.
            if !profile.sagas.isEmpty || profile.bookCount > 0 {
                Section {
                    if !profile.sagas.isEmpty {
                        NavigationLink {
                            FriendSeriesListView(
                                friendId: friend.userId,
                                friendName: friend.displayName,
                                isPreview: isPreview
                            )
                        } label: {
                            Label(
                                profile.sagas.count == 1
                                    ? "1 série"
                                    : "\(profile.sagas.count) séries",
                                systemImage: "books.vertical"
                            )
                        }
                        .edgeToEdgeSeparator()
                        .accessibilityIdentifier("friend-see-series")
                    }
                    if profile.bookCount > 0 {
                        NavigationLink {
                            FriendLibraryView(
                                friendId: friend.userId,
                                friendName: friend.displayName,
                                isPreview: isPreview
                            )
                        } label: {
                            Label(
                                profile.bookCount == 1
                                    ? "1 livre"
                                    : "\(profile.bookCount) livres",
                                systemImage: "book"
                            )
                        }
                        .edgeToEdgeSeparator()
                        .accessibilityIdentifier("friend-see-library")
                    }
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

    /// A section heading followed by a red heart: the favourites' sections.
    private func hearted(_ title: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            Text(title)
            Image(systemName: "heart.fill").foregroundStyle(.red)
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

    private func add(_ saga: FriendSaga, as format: BookFormat) async {
        guard let first = saga.volumes.first else { return }
        addingSagas.insert(saga.id)
        defer { addingSagas.remove(saga.id) }
        do {
            try await FriendsAPI.addBook(
                friendId: friend.userId,
                bookId: first.id,
                status: .toRead,
                format: format
            )
            markOwned(first.id)
            if let index = profile?.sagas.firstIndex(where: { $0.id == saga.id }) {
                profile?.sagas[index].inLibrary = true
            }
        } catch {
            addFailed = reportError(error)
        }
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
        self.profile = profile
        write()
    }
}

extension FriendProfile {
    static let preview: FriendProfile = {
        let hunter = FriendBook(
            book: Book(
                id: "hunter", title: "Primal Hunter", authors: ["Zogarth"], format: .audiobook,
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
            pile: [],
            favorites: [dune, wind] + favorites,
            sagas: [],
            lastFinished: wind,
            bookCount: 9,
            readThisYear: 2
        )
    }()
}

#Preview("Recent activity") {
    NavigationStack {
        FriendProfileView(preview: .preview)
    }
}
