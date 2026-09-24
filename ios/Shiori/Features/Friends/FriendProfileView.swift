import SwiftUI

/// One friend's shelf: what they are reading, their pile, what they keep close
/// and the sagas they are working through — and the place to take any of it
/// onto the reader's own shelf.
///
/// Read-only as far as the friend's library goes. A row opens the friend's
/// book on a page with no control that writes to it; what it offers instead is
/// to add the book to the reader's pile, which "+" does from the row itself,
/// greyed out on a book the reader already owns.
///
/// Books they marked "do not share" are absent, and no reading note is drawn:
/// a friend sees a shelf, not a diary.
///
/// The reader's own shelf opens on this very page, as a preview: drawn from
/// the shelf they already hold, every "+" greyed out since every book is
/// theirs, and each row opening the page a friend would open.
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
    /// How many books in progress are shown: three at first, three more on
    /// each "Voir plus".
    @State private var readingShown = FriendProfileView.readingStep
    /// The sagas being added from their row, each showing its own spinner.
    @State private var addingSagas: Set<String> = []

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
            // What moved lately, under the figures, so a friend coming back
            // finds what changed rather than the same lists. A book read or
            // finished brings its saga along, covers and all. A saga is not
            // opened: the catalogue is not something a friendship opens.
            let recent = profile.recentActivity()
            if !recent.isEmpty {
                Section("Activités récentes") {
                    ForEach(recent) { activity in
                        if let entry = activity.book {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top, spacing: 8) {
                                    RecentActivityRow(activity: activity)
                                        .contentShape(.rect)
                                        .onTapGesture { openBook = entry }
                                    takeButton(entry)
                                }
                                if let saga = profile.saga(of: entry.book) {
                                    SagaRow(saga: saga, showsCovers: true)
                                }
                            }
                            .edgeToEdgeSeparator()
                        } else {
                            RecentActivityRow(activity: activity)
                                .edgeToEdgeSeparator()
                        }
                    }
                }
            }
            // The book the recent activity already leads with is not listed
            // again: the rest, the one touched last first — all of them up to
            // four, else three and "Voir plus" for the next three. A last
            // step that would hide a single book shows it instead.
            let leading = recent.first { if case .reading = $0 { true } else { false } }?.book?.id
            let reading = profile.reading.filter { $0.id != leading }
            let shown = reading.count - readingShown <= 1 ? reading.count : readingShown
            // A section with nothing in it is not drawn at all.
            if !reading.isEmpty {
                shelf(
                    "En cours",
                    books: Array(reading.prefix(shown)),
                    empty: "",
                    showsSeries: true,
                    hidden: reading.count - shown
                )
            }
            // A hearted saga stands for its volumes: the books below it are
            // the hearts it does not already cover.
            if !profile.favoriteSagas.isEmpty {
                Section {
                    ForEach(profile.favoriteSagasByActivity) { saga in
                        HStack(alignment: .top, spacing: 8) {
                            SagaRow(saga: saga, showsCovers: true)
                            TakeButton(
                                owned: saga.inLibrary || isPreview || saga.volumes.isEmpty,
                                isAdding: addingSagas.contains(saga.id),
                                addLabel: "Ajouter la série à mes séries",
                                ownedLabel: "Série déjà dans votre bibliothèque"
                            ) {
                                await add(saga)
                            }
                        }
                        .edgeToEdgeSeparator()
                    }
                } header: {
                    hearted("Séries")
                }
            }
            if !profile.favorites.isEmpty {
                shelf(
                    "Livres",
                    hearted: true,
                    books: profile.favoritesByActivity,
                    empty: "",
                    asFavorites: true
                )
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

    /// A section heading followed by a red heart: the favourites' sections.
    private func hearted(_ title: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            Text(title)
            Image(systemName: "heart.fill").foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private func shelf(
        _ title: LocalizedStringKey,
        hearted isHearted: Bool = false,
        books: [FriendBook],
        empty: LocalizedStringKey,
        // Books in progress name their saga: "Tome 3" of what, otherwise.
        showsSeries: Bool = false,
        // Every favourite is hearted: the heart, the status and the stars
        // would say much the same on every row, and are left out.
        asFavorites: Bool = false,
        // How many more books "Voir plus" would show.
        hidden: Int = 0
    ) -> some View {
        Section {
            if books.isEmpty {
                Text(empty).font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(books) { entry in
                    HStack(alignment: .top, spacing: 8) {
                        BookRow(
                            title: entry.book.title,
                            authorLine: entry.book.authorLine,
                            cover: entry.book,
                            status: entry.book.status,
                            // The stars and the genre together would squeeze
                            // the title of a favourite to a few letters.
                            rating: asFavorites ? nil : entry.book.rating,
                            volumeLabel: showsSeries ? nil : entry.book.series?.label,
                            series: showsSeries ? entry.book.series : nil,
                            genre: entry.book.genre,
                            subgenre: asFavorites ? nil : entry.book.subgenres.first,
                            language: entry.book.language,
                            isFavorite: asFavorites ? false : entry.book.favorite
                        )
                        .contentShape(.rect)
                        .onTapGesture { openBook = entry }
                        takeButton(entry)
                    }
                    .edgeToEdgeSeparator()
                    .accessibilityIdentifier("friend-book-row")
                }
                if hidden > 0 {
                    Button {
                        withAnimation { readingShown += Self.readingStep }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Voir plus")
                            Image(systemName: "chevron.down").font(.caption.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .edgeToEdgeSeparator()
                    .accessibilityIdentifier("friend-shelf-more")
                }
            }
        } header: {
            if isHearted { hearted(title) } else { Text(title) }
        }
    }

    /// "+" to put a book on the reader's pile, greyed out on one they already
    /// own — every book of the preview, which is their own shelf.
    private func takeButton(_ entry: FriendBook) -> some View {
        TakeButton(owned: entry.inLibrary || isPreview, isAdding: adding.contains(entry.id)) {
            await add(entry)
        }
    }

    private static let readingStep = 3

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

    private func add(_ saga: FriendSaga) async {
        guard let first = saga.volumes.first else { return }
        addingSagas.insert(saga.id)
        defer { addingSagas.remove(saga.id) }
        do {
            try await FriendsAPI.addBook(friendId: friend.userId, bookId: first.id, status: .toRead)
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
    }
}
