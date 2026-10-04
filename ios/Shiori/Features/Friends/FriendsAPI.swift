import Foundation

/// Somebody the reader shares libraries with.
struct Friend: Identifiable, Codable, Sendable {
    var id: String { userId }
    let userId: String
    /// Nil for an account that never finished its onboarding.
    let firstName: String?
    let since: Date
    /// Their shelf in figures, the books they keep to themselves left out.
    /// Every book they share, the dropped ones aside.
    var bookCount = 0
    var favoriteCount = 0
    var readingCount = 0
    var toReadCount = 0
    /// Books they finished since January 1st: what the reading challenge
    /// ranks them by.
    var readThisYear = 0
    /// What moved last on their shelf, one book per kind, undated by any
    /// window: the list keeps what is still recent when it draws them.
    var recentActivity: [RecentActivity] = []

    var displayName: String {
        firstName ?? String(localized: "Un lecteur")
    }

    /// One or two letters for the avatar.
    var initials: String {
        let letters = displayName.split(separator: " ").prefix(2).compactMap(\.first)
        return String(letters).uppercased()
    }
}

extension Friend {
    /// The reader as their friends list them, drawn from their own shelf: the
    /// counts are those of the lists the shelf shows, a hearted saga counting
    /// once for its volumes.
    init(seenByFriends shelf: FriendProfile) {
        self.init(
            userId: shelf.userId,
            firstName: shelf.firstName,
            since: .now,
            bookCount: shelf.bookCount,
            favoriteCount: shelf.favorites.count + shelf.favoriteSagas.count,
            readingCount: shelf.reading.count,
            toReadCount: shelf.pile.count,
            readThisYear: shelf.readThisYear,
            recentActivity: shelf.recentActivity()
        )
    }
}

/// A book on a friend's shelf, and whether the reader already owns the story —
/// same title and first author, whatever the edition.
struct FriendBook: Identifiable, Hashable, Codable, Sendable {
    var id: String { book.id }
    var book: Book
    var inLibrary: Bool
    /// When its owner hearted it. Nil on a book not hearted, and on a heart
    /// given before the date was kept.
    var favoritedAt: Date?
    /// When its owner last did anything with it: picked it up, moved its
    /// status, or had a listening sync move its position.
    var lastActivityAt: Date?
}

/// Whether a friend's book can be taken as an audiobook: a recording is, a
/// printed book is when Audible sells it in its language. Unknown when Audible
/// could not be asked — the reader then decides, as before anybody asked.
enum AudioAvailability: Sendable {
    case available, unavailable, unknown
}

/// Where a book taken from somebody else's shelf lands on the reader's own.
enum CopiedStatus: Sendable {
    case toRead, read

    var graphQL: ShioriGraphQL.CopiedStatus {
        switch self {
        case .toRead: .toRead
        case .read: .read
        }
    }
}

/// One saga a friend is working through, as their own books describe it. The
/// shared catalogue is never exposed, so this says how many volumes they hold
/// and never how many the saga has.
struct FriendSaga: Identifiable, Codable, Sendable {
    let id: String
    /// The saga alone, whatever the language: what its page opens on.
    let seriesId: String
    let name: String
    /// The saga heard rather than read: held both ways, it is two sagas under
    /// one name, and the headphones tell them apart.
    var isAudio = false
    let author: String?
    let language: BookLanguage?
    let ownedCount: Int
    /// Hearted by its owner. It then stands for its volumes among the
    /// favourites, which do not list them again one by one.
    let favorite: Bool
    /// When its owner hearted it. Nil on a saga not hearted, and on a heart
    /// given before the date was kept.
    var favoritedAt: Date?
    /// Their stars for the saga as a whole. Nil on a saga they did not rate.
    var rating: Int?
    let genre: BookGenre?
    let subgenre: String?
    /// Its volumes on the shelf, in reading order, for a strip of covers:
    /// carried by a hearted saga and by those of the recent activity.
    var volumes: [Book] = []
    /// The last time its owner did anything with one of those volumes.
    var lastActivityAt: Date?
    /// The reader already holds a volume of it: nothing to take.
    var inLibrary = false
    /// The latest day one of its volumes was shelved on.
    var shelvedAt: Date?
    /// Where they stand on it, read off their own volumes.
    var state: SeriesState?
}

/// A friend's shelf at a glance.
struct FriendProfile: Codable, Sendable {
    let userId: String
    let firstName: String?
    /// Most recently active first.
    var reading: [FriendBook]
    var pile: [FriendBook]
    /// The hearted books a hearted saga does not already stand for.
    var favorites: [FriendBook]
    var sagas: [FriendSaga]
    /// The book they finished most recently, when one carries its date.
    var lastFinished: FriendBook?
    /// The book they dropped most recently.
    var lastDropped: FriendBook?
    /// The book they shelved most recently.
    var lastAdded: FriendBook?
    /// How many books their library shows, the dropped ones aside.
    var bookCount = 0
    /// Books they finished since January 1st, as the friends list counts them.
    var readThisYear = 0

    /// The hearted sagas, the most recently hearted first; those hearted
    /// before the date was kept follow in alphabetical order.
    var favoriteSagas: [FriendSaga] {
        let hearted = sagas.filter(\.favorite)
        return hearted.filter { $0.favoritedAt != nil }
            .sorted { ($0.favoritedAt ?? .distantPast) > ($1.favoritedAt ?? .distantPast) }
            + hearted.filter { $0.favoritedAt == nil }
    }

    /// The hearted sagas in the Series tab's order: the one whose latest
    /// volume was shelved last first, then by name.
    var favoriteSagasByShelf: [FriendSaga] {
        favoriteSagas.sorted {
            let left = $0.shelvedAt ?? .distantPast, right = $1.shelvedAt ?? .distantPast
            return left != right ? left > right : $0.name.localizedCompare($1.name) == .orderedAscending
        }
    }

    /// The hearted books in the Library tab's order: newest first on the day
    /// each was shelved — finished, else started, else added — then by title.
    var favoritesByShelf: [FriendBook] {
        favorites.sorted {
            let left = $0.book.shelvedAt ?? .distantPast, right = $1.book.shelvedAt ?? .distantPast
            return left != right ? left > right : $0.book.title.localizedCompare($1.book.title) == .orderedAscending
        }
    }

    /// What moved on the shelf, one book of each kind at most, always in the
    /// same order: the book in progress touched last, the last book finished,
    /// the last one hearted, the last one added and the last one dropped. The
    /// heart is news however long ago it was given; the others only within
    /// thirty days. What a
    /// friend coming back looks for, rather than the same lists as last time.
    func recentActivity(now: Date = .now) -> [RecentActivity] {
        let reading = self.reading.first.flatMap { entry in
            entry.lastActivityAt.map { RecentActivity.reading(entry, at: $0) }
        }
        let finished = lastFinished.flatMap { entry in
            entry.book.finishedAt.map { RecentActivity.finished(entry, at: $0) }
        }
        let dropped = lastDropped.flatMap { entry in
            entry.lastActivityAt.map { RecentActivity.dropped(entry, at: $0) }
        }
        let added = lastAdded.flatMap { entry in
            entry.book.addedAt.map { RecentActivity.added(entry, at: $0) }
        }
        // What they last chose to keep close is news whenever it was.
        let heart = favorites.compactMap { entry in
            entry.favoritedAt.map { RecentActivity.hearted(entry, at: $0) }
        }
        .max { $0.date < $1.date }
        return [reading, finished, heart, added, dropped]
            .compactMap(\.self)
            .filter { $0.isRecent(now: now) }
    }

    var displayName: String {
        firstName ?? String(localized: "Un lecteur")
    }

    var isEmpty: Bool {
        reading.isEmpty && pile.isEmpty && favorites.isEmpty && sagas.isEmpty && bookCount == 0
    }
}

/// One book that moved on a shelf lately, with its day: picked up or read
/// on, finished, hearted, added, or dropped.
enum RecentActivity: Identifiable, Codable, Sendable {
    case reading(FriendBook, at: Date)
    case finished(FriendBook, at: Date)
    case dropped(FriendBook, at: Date)
    case hearted(FriendBook, at: Date)
    case added(FriendBook, at: Date)

    /// How far back "lately" goes.
    static let window: TimeInterval = 30 * 24 * 3600

    /// Still news: within the window, or a heart, which is news whenever it
    /// was given.
    func isRecent(now: Date = .now) -> Bool {
        if case .hearted = self { return true }
        return date >= now.addingTimeInterval(-Self.window)
    }

    var id: String {
        switch self {
        case .reading: "reading-\(book.id)"
        case .finished: "finished-\(book.id)"
        case .dropped: "dropped-\(book.id)"
        case .added: "added-\(book.id)"
        case .hearted: "hearted-\(book.id)"
        }
    }

    var book: FriendBook {
        switch self {
        case let .reading(entry, _), let .finished(entry, _), let .dropped(entry, _),
             let .hearted(entry, _), let .added(entry, _): entry
        }
    }

    var date: Date {
        switch self {
        case let .reading(_, date), let .finished(_, date), let .dropped(_, date),
             let .hearted(_, date), let .added(_, date): date
        }
    }
}

/// A heart one friend gave lately, as the dashboard shows it: a saga or a book,
/// whose, and when.
struct FriendFavorite: Identifiable, Codable, Sendable {
    let friendId: String
    /// Nil for an account that never finished its onboarding.
    let friendName: String?
    let favoritedAt: Date
    var book: FriendBook?
    /// Carries its first volume only, the cover its tile draws.
    var saga: FriendSaga?

    var id: String { "\(friendId)-\(book?.id ?? saga?.id ?? "")" }

    var friendDisplayName: String {
        friendName ?? String(localized: "Un lecteur")
    }

    /// The book a tap opens: the one hearted, or the first volume of the saga.
    var openedBook: Book? { book?.book ?? saga?.volumes.first }

    /// What its tile draws: the book, else the saga under its own name with
    /// its first volume's cover.
    var tile: Book {
        if let book { return book.book }
        let first = saga?.volumes.first
        return Book(
            id: saga?.id ?? id,
            title: saga?.name ?? "",
            authors: saga?.author.map { [$0] } ?? [],
            format: saga?.isAudio == true ? .audiobook : .book,
            language: saga?.language,
            series: first?.series,
            coverURL: first?.coverURL,
            status: first?.status ?? .toRead
        )
    }
}

/// The invitation the reader passes on. One at a time: asking again answers the
/// one already standing rather than leaving another key to their library out.
struct FriendInvitation: Sendable {
    let code: String
    let expiresAt: Date

    /// The link to share. It opens the app straight on the invitation when
    /// Shiori is installed, and otherwise a page that says what to do with the
    /// code, so it means something to somebody who does not have Shiori yet.
    var url: URL { InvitationLink.url(code: code) }
}

enum FriendsAPI {
    static func friends() async throws -> [Friend] {
        #if DEBUG
        if Showcase.isOn {
            return Showcase.friends
        }
        #endif
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.FriendsQuery()
        )
        return data.friends.map { Friend(row: $0.fragments.friendRow) }
    }

    /// What every friend hearted in the last thirty days, the newest first.
    static func recentFavorites() async throws -> [FriendFavorite] {
        #if DEBUG
        if Showcase.isOn {
            return Showcase.recentFavorites
        }
        #endif
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.FriendFavoritesQuery()
        )
        return data.friendFavorites.map { row in
            FriendFavorite(
                friendId: row.friendId,
                friendName: row.friendName,
                favoritedAt: GraphQLHelpers.parseISO8601(row.favoritedAt) ?? .now,
                book: row.book.map { FriendBook(row: $0.fragments.friendBookRow) },
                saga: row.saga.map { FriendSaga(row: $0.fragments.friendSagaRow) }
            )
        }
    }

    /// Nil for anybody the reader is not friends with, which is also the answer
    /// for an id that names nobody.
    static func profile(userId: String) async throws -> FriendProfile? {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.FriendProfileQuery(userId: userId)
        )
        return data.friendProfile.map { FriendProfile(shelf: $0.fragments.sharedShelf) }
    }

    /// The reader's own shelf, exactly as their friends see it: the books they
    /// keep to themselves left out, in full rather than the thirty a friend is
    /// shown of each list.
    static func myShelf() async throws -> FriendProfile {
        #if DEBUG
        if Showcase.isOn {
            return Showcase.myShelf
        }
        #endif
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.MyShelfQuery()
        )
        return FriendProfile(shelf: data.myShelf.fragments.sharedShelf)
    }

    /// One page of a friend's library — or of the reader's own, previewed —
    /// newest first on the day each book was shelved.
    static func libraryPage(
        friendId: String,
        status: ReadingStatus?,
        after: String?
    ) async throws -> (books: [FriendBook], hasMore: Bool) {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.FriendLibraryPageQuery(
                userId: friendId,
                status: GraphQLHelpers.graphQLNullable(status.map(LibraryAPI.graphQLStatus)),
                after: GraphQLHelpers.graphQLNullable(after)
            )
        )
        guard let page = data.friendLibraryPage else { return ([], false) }
        return (page.books.map { FriendBook(row: $0.fragments.friendBookRow) }, page.hasMore)
    }

    /// One page of a friend's sagas, each with every volume as a cover.
    static func sagaPage(
        friendId: String,
        state: SeriesState?,
        loved: Bool,
        after: String?
    ) async throws -> (sagas: [FriendSaga], hasMore: Bool) {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.FriendSagaPageQuery(
                userId: friendId,
                state: GraphQLHelpers.graphQLNullable(state.map { .case(SeriesAPI.graphQLState($0)) }),
                loved: loved ? .some(true) : .none,
                after: GraphQLHelpers.graphQLNullable(after)
            )
        )
        guard let page = data.friendSagaPage else { return ([], false) }
        return (page.sagas.map { FriendSaga(row: $0.fragments.friendSagaRow) }, page.hasMore)
    }

    /// A saga opened from a friend's shelf: the catalogue, and where the
    /// friend stands on it. The saga is nil when they share no volume of it.
    static func sagaScreen(
        friendId: String,
        seriesId: String,
        language: BookLanguage?
    ) async throws -> (series: BookSeries?, saga: FriendSaga?) {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.FriendSeriesScreenQuery(
                userId: friendId,
                id: seriesId,
                language: SeriesAPI.graphQLLanguage(language)
            ),
            requestTimeout: SeriesAPI.firstOpeningTimeout
        )
        return (
            series: data.series.map { BookSeries(catalogue: $0.fragments.seriesCatalogue) },
            saga: data.friendSaga.map { FriendSaga(row: $0.fragments.friendSagaRow) }
        )
    }

    /// One book of a friend's shelf, with everything the read-only page shows.
    /// Nil for a book they keep to themselves, and for anybody who is not a
    /// friend.
    /// "Coups de cœur de vos amis", for Découvrir: what the friends hearted
    /// and the reader holds in no format.
    static func picks() async throws -> FriendPicks {
        #if DEBUG
        if Showcase.isOn {
            return Showcase.picks
        }
        #endif
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.FriendRecommendationsQuery()
        )
        let found = data.friendRecommendations
        return FriendPicks(
            books: found.books.map { row in
                let lovers = row.fragments.friendLovedBookLovers
                return LovedBook(
                    book: FriendBook(row: row.book.fragments.friendBookRow),
                    lovers: FriendLovers(
                        friends: lovers.friends.map { .init(userId: $0.userId, firstName: $0.firstName) },
                        lovedByMany: lovers.lovedByMany
                    )
                )
            },
            sagas: found.sagas.map { row in
                let lovers = row.fragments.friendLovedSagaLovers
                return LovedSaga(
                    saga: FriendSaga(row: row.saga.fragments.friendSagaRow),
                    lovers: FriendLovers(
                        friends: lovers.friends.map { .init(userId: $0.userId, firstName: $0.firstName) },
                        lovedByMany: lovers.lovedByMany
                    )
                )
            },
            authors: found.authors.map { row in
                let lovers = row.fragments.friendLovedAuthorLovers
                return LovedAuthor(
                    key: row.author.key,
                    name: row.author.name,
                    portraitURL: row.author.portraitUrl.flatMap(URL.init(string:)),
                    lovers: FriendLovers(
                        friends: lovers.friends.map { .init(userId: $0.userId, firstName: $0.firstName) },
                        lovedByMany: lovers.lovedByMany
                    )
                )
            }
        )
    }

    /// Whether the reader may take a friend's book as an audiobook. Nil for a
    /// book that is not shared with them.
    static func audio(friendId: String, bookId: String) async throws -> AudioAvailability? {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.FriendBookAudioQuery(userId: friendId, bookId: bookId)
        )
        guard let answer = data.friendBookAudio else { return nil }
        return switch answer.value {
        case .available: .available
        case .unavailable: .unavailable
        case .unknown, nil: .unknown
        }
    }

    static func book(friendId: String, bookId: String) async throws -> FriendBook? {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.FriendBookQuery(userId: friendId, bookId: bookId)
        )
        guard let row = data.friendBook else { return nil }
        var friendBook = FriendBook(row: row.fragments.friendBookRow)
        friendBook.book.publisher = row.publisher
        friendBook.book.firstPublishedIn = row.firstPublishedIn
        friendBook.book.synopsis = row.synopsis
        friendBook.book.pageCount = row.pageCount
        friendBook.book.durationMinutes = row.durationMinutes
        friendBook.book.narrators = row.narrators
        friendBook.book.isbn13 = row.isbn13
        friendBook.book.audibleURL = row.audibleUrl.flatMap(URL.init(string:))
        friendBook.book.amazonURL = URL(string: row.amazonUrl)
        friendBook.book.listeningProgress = row.listeningProgress.map { Int($0) }
        friendBook.book.addedAt = GraphQLHelpers.parseISO8601(row.addedAt)
        friendBook.book.startedAt = row.startedAt.flatMap(GraphQLHelpers.parseISO8601)
        return friendBook
    }

    /// Put a friend's book on the reader's shelf, in the format the reader
    /// takes it in. The server copies it from the friend's record and names
    /// them as who recommended it.
    @discardableResult
    static func addBook(
        friendId: String,
        bookId: String,
        status: CopiedStatus,
        format: BookFormat
    ) async throws -> String {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.AddFriendBookMutation(
                userId: friendId,
                bookId: bookId,
                status: .case(status.graphQL),
                format: .some(LibraryAPI.graphQLFormat(format))
            )
        )
        return data.addFriendBook.id
    }

    static func invite() async throws -> FriendInvitation {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.InviteFriendMutation(),
            changesLibrary: false
        )
        return FriendInvitation(
            code: data.inviteFriend.code,
            expiresAt: GraphQLHelpers.parseISO8601(data.inviteFriend.expiresAt) ?? .now
        )
    }

    /// Takes an invitation up, by its code or by the link carrying it: the
    /// server pulls the code out of whatever the reader pasted.
    static func accept(code: String) async throws -> Friend {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.AcceptFriendInvitationMutation(code: code),
            changesLibrary: false
        )
        return Friend(row: data.acceptFriendInvitation.fragments.friendRow)
    }

    @discardableResult
    static func remove(userId: String) async throws -> Bool {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.RemoveFriendMutation(userId: userId),
            changesLibrary: false
        )
        return data.removeFriend
    }
}

private extension Friend {
    init(row: ShioriGraphQL.FriendRow) {
        self.init(
            userId: row.userId,
            firstName: row.firstName,
            since: GraphQLHelpers.parseISO8601(row.since) ?? .now,
            bookCount: row.bookCount,
            favoriteCount: row.favoriteCount,
            readingCount: row.readingCount,
            toReadCount: row.toReadCount,
            readThisYear: row.readThisYear,
            recentActivity: row.recentActivity.compactMap(RecentActivity.init(row:))
        )
    }
}

private extension RecentActivity {
    /// A book of the friends list: a cover and its title, all a tile draws.
    init?(row: ShioriGraphQL.FriendRow.RecentActivity) {
        guard let at = GraphQLHelpers.parseISO8601(row.at), let kind = row.kind.value else { return nil }
        let status: ReadingStatus = switch kind {
        case .reading: .reading
        case .read: .read
        case .dropped: .dropped
        case .hearted, .added: .toRead
        }
        let entry = FriendBook(
            book: Book(
                id: row.bookId,
                title: row.title,
                authors: [],
                format: row.format.asDomain,
                coverURL: row.coverUrl.flatMap(URL.init(string:)),
                status: status
            ),
            inLibrary: false
        )
        self = switch kind {
        case .reading: .reading(entry, at: at)
        case .read: .finished(entry, at: at)
        case .hearted: .hearted(entry, at: at)
        case .added: .added(entry, at: at)
        case .dropped: .dropped(entry, at: at)
        }
    }
}

private extension FriendProfile {
    init(shelf: ShioriGraphQL.SharedShelf) {
        self.init(
            userId: shelf.userId,
            firstName: shelf.firstName,
            reading: shelf.reading.map { FriendBook(row: $0.fragments.friendBookRow) },
            pile: shelf.pile.map { FriendBook(row: $0.fragments.friendBookRow) },
            favorites: shelf.favorites.map { FriendBook(row: $0.fragments.friendBookRow) },
            sagas: shelf.sagas.map { FriendSaga(row: $0.fragments.friendSagaRow) },
            lastFinished: shelf.lastFinished.map { FriendBook(row: $0.fragments.friendBookRow) },
            lastDropped: shelf.lastDropped.map { FriendBook(row: $0.fragments.friendBookRow) },
            lastAdded: shelf.lastAdded.map { FriendBook(row: $0.fragments.friendBookRow) },
            bookCount: shelf.bookCount,
            readThisYear: shelf.readThisYear
        )
    }
}

private extension FriendSaga {
    init(row: ShioriGraphQL.FriendSagaRow) {
        self.init(
            id: row.id,
            seriesId: row.seriesId,
            name: row.name,
            isAudio: row.audio,
            author: row.author,
            language: row.language?.asDomain,
            ownedCount: row.ownedCount,
            favorite: row.favorite,
            favoritedAt: row.favoritedAt.flatMap(GraphQLHelpers.parseISO8601),
            rating: row.rating,
            genre: row.genre?.asDomain,
            subgenre: row.subgenre,
            volumes: row.volumes.map { Book(row: $0.fragments.friendBookRow) },
            lastActivityAt: row.volumes
                .compactMap { GraphQLHelpers.parseISO8601($0.fragments.friendBookRow.lastActivityAt) }
                .max(),
            inLibrary: row.volumes.contains { $0.fragments.friendBookRow.inLibrary },
            shelvedAt: GraphQLHelpers.parseISO8601(row.shelvedAt),
            state: row.state.asDomain
        )
    }
}

private extension FriendBook {
    init(row: ShioriGraphQL.FriendBookRow) {
        self.init(
            book: Book(row: row),
            inLibrary: row.inLibrary,
            favoritedAt: row.favoritedAt.flatMap(GraphQLHelpers.parseISO8601),
            lastActivityAt: GraphQLHelpers.parseISO8601(row.lastActivityAt)
        )
    }
}

private extension Book {
    /// A friend's book, drawn by the same row as the reader's own. Everything
    /// the row needs is here; the note is not, and has no field to come from.
    init(row: ShioriGraphQL.FriendBookRow) {
        self.init(
            id: row.id,
            title: row.title,
            authors: row.authors,
            format: row.format.asDomain,
            genre: row.genre?.asDomain,
            subgenres: row.subgenres,
            language: row.language?.asDomain,
            series: row.series.map {
                SeriesMembership(
                    id: $0.id,
                    name: $0.name,
                    volume: $0.volume,
                    kind: $0.kind.asDomain
                )
            },
            coverURL: row.coverUrl.flatMap(URL.init(string:)),
            status: row.status.asDomain,
            rating: row.rating,
            favorite: row.favorite,
            addedAt: GraphQLHelpers.parseISO8601(row.addedAt),
            startedAt: row.startedAt.flatMap(GraphQLHelpers.parseISO8601),
            finishedAt: row.finishedAt.flatMap(GraphQLHelpers.parseISO8601),
            shelvedAt: GraphQLHelpers.parseISO8601(row.shelvedAt)
        )
    }
}
