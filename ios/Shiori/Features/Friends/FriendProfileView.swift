import SwiftUI

/// One friend's shelf: what they are reading, their pile, what they keep close
/// and the sagas they are working through — and the place to take any of it
/// onto the reader's own shelf.
///
/// Read-only as far as the friend's library goes. A row opens the friend's
/// book on a page with no control that writes to it; what it offers instead is
/// to add the book to the reader's pile, which "+ Pile" does from the row
/// itself. A book the reader already owns says "Chez vous" instead.
///
/// Books they marked "do not share" are absent, and no reading note is drawn:
/// a friend sees a shelf, not a diary.
///
/// The reader's own shelf opens on this very page, as a preview: drawn from
/// the shelf they already hold, every "+ Pile" shown the way a friend who owns
/// none of it would see it, greyed out, and no row opening anything.
struct FriendProfileView: View {
    let friend: Friend
    private let isPreview: Bool

    @State private var profile: FriendProfile?
    @State private var isLoading: Bool
    @State private var errorMessage: String?
    @State private var openBook: FriendBook?
    /// The books being added from their row, each showing its own spinner.
    @State private var adding: Set<String> = []
    @State private var addFailed: String?

    init(friend: Friend) {
        self.friend = friend
        isPreview = false
        _isLoading = State(initialValue: true)
    }

    /// The reader's own page as their friends see it.
    init(preview shelf: FriendProfile) {
        friend = Friend(seenByFriends: shelf)
        isPreview = true
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
                EmptyStateView(
                    systemImage: "books.vertical",
                    title: "Rien à voir pour l'instant",
                    verbatim: String(localized: "\(friend.displayName) n'a encore rien à partager.")
                )
            }
        }
        .navigationTitle(profile?.displayName ?? friend.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task { if !isPreview { await load() } }
        .toolbar { if isPreview { shareFavorites } }
        .navigationDestination(item: $openBook) { book in
            FriendBookView(
                friendId: friend.userId,
                bookId: book.id,
                friendName: friend.displayName,
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
            shelf("En cours", books: profile.reading, empty: "Aucune lecture en cours.", showsSeries: true)
            // What is new among the favourites, so a friend coming back finds
            // what changed rather than the same list. A saga is not opened:
            // the catalogue is not something a friendship opens.
            let recent = profile.recentFavorites()
            if !recent.isEmpty {
                Section("Récemment dans ses favoris") {
                    ForEach(recent) { favorite in
                        switch favorite {
                        case .saga:
                            RecentFavoriteRow(favorite: favorite)
                        case let .book(entry, _):
                            RecentFavoriteRow(favorite: favorite)
                                .contentShape(.rect)
                                .onTapGesture { if !isPreview { openBook = entry } }
                        }
                    }
                }
            }
            // A hearted saga stands for its volumes: the books below it are
            // the hearts it does not already cover.
            if !profile.favoriteSagas.isEmpty {
                Section("Ses séries favorites") {
                    ForEach(profile.favoriteSagas) { saga in
                        SagaRow(saga: saga, showsCovers: true)
                    }
                }
            }
            shelf(
                "Ses livres favoris",
                books: profile.favorites,
                empty: "Aucun livre favori.",
                showsStatus: true
            )
            if !profile.sagas.isEmpty {
                Section("Ses séries") {
                    ForEach(profile.sagas) { saga in
                        SagaRow(saga: saga)
                    }
                }
            }
            shelf("Sa pile à lire", books: profile.pile, empty: "Sa pile est vide.")
        }
        .listStyle(.insetGrouped)
        .refreshable { if !isPreview { await load() } }
    }

    /// The preview keeps what the favourites list used to offer: the whole
    /// list as text, for a mail, a message, or the clipboard. Copy has its own
    /// entry: the system sheet does not always offer it for plain text.
    @ToolbarContentBuilder
    private var shareFavorites: some ToolbarContent {
        if let profile, !(profile.favoriteSagas.isEmpty && profile.favorites.isEmpty) {
            let text = FavoritesSharing.text(
                sagas: profile.favoriteSagas,
                books: profile.favorites.map(\.book)
            )
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ShareLink(
                        item: text,
                        subject: Text("Mes favoris"),
                        preview: SharePreview(Text("Mes favoris"))
                    ) {
                        Label("Envoyer…", systemImage: "paperplane")
                    }
                    Button {
                        UIPasteboard.general.string = text
                    } label: {
                        Label("Copier la liste", systemImage: "doc.on.doc")
                    }
                    .accessibilityIdentifier("my-shelf-copy-favorites")
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

    @ViewBuilder
    private func shelf(
        _ title: LocalizedStringKey,
        books: [FriendBook],
        empty: LocalizedStringKey,
        // Only the favourites mix statuses: the other shelves are one each,
        // and their heading already says which.
        showsStatus: Bool = false,
        // Books in progress name their saga: "Tome 3" of what, otherwise.
        showsSeries: Bool = false
    ) -> some View {
        Section(title) {
            if books.isEmpty {
                Text(empty).font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(books) { entry in
                    HStack(spacing: 8) {
                        BookRow(
                            title: entry.book.title,
                            authorLine: entry.book.authorLine,
                            cover: entry.book,
                            status: entry.book.status,
                            rating: entry.book.rating,
                            volumeLabel: showsSeries ? nil : entry.book.series?.label,
                            series: showsSeries ? entry.book.series : nil,
                            statusTag: showsStatus ? entry.book.status : nil,
                            genre: entry.book.genre,
                            subgenre: entry.book.subgenres.first,
                            language: entry.book.language,
                            isFavorite: entry.book.favorite
                        )
                        .contentShape(.rect)
                        .onTapGesture { if !isPreview { openBook = entry } }
                        takeButton(entry)
                    }
                    .accessibilityIdentifier("friend-book-row")
                }
            }
        }
    }

    /// "+ Pile" on a book the reader does not have, "Chez vous" on one they do.
    /// The preview shows "+ Pile" on every row, greyed out: every book on the
    /// shelf is the reader's own, and "Chez vous" is not what a friend sees.
    @ViewBuilder
    private func takeButton(_ entry: FriendBook) -> some View {
        if isPreview {
            // Disabled alone leaves the plus in the accent colour: grey
            // throughout, so it reads as inert at a glance.
            pileButton(entry)
                .foregroundStyle(.tertiary)
                .disabled(true)
        } else if entry.inLibrary {
            Text("Chez vous")
                .font(.caption.weight(.medium))
                .foregroundStyle(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.green.opacity(0.15), in: .capsule)
                .accessibilityIdentifier("friend-book-owned")
        } else if adding.contains(entry.id) {
            ProgressView().frame(width: 56)
        } else {
            pileButton(entry)
        }
    }

    private func pileButton(_ entry: FriendBook) -> some View {
        Button {
            Task { await add(entry) }
        } label: {
            Label("Pile", systemImage: "plus")
                .font(.caption.weight(.medium))
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
        .accessibilityLabel(Text("Ajouter à ma pile"))
        .accessibilityIdentifier("friend-book-add")
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            profile = try await FriendsAPI.profile(userId: friend.userId)
        } catch {
            errorMessage = reportError(error)
        }
        isLoading = false
    }

    private func add(_ entry: FriendBook) async {
        adding.insert(entry.id)
        defer { adding.remove(entry.id) }
        do {
            try await FriendsAPI.addBook(friendId: friend.userId, bookId: entry.id, status: .toRead)
            markOwned(entry.id)
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
        self.profile = profile
    }
}
