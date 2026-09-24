import Foundation

/// Somebody the reader shares libraries with.
struct Friend: Identifiable, Sendable {
    var id: String { userId }
    let userId: String
    /// Nil for an account that never finished its onboarding.
    let firstName: String?
    let since: Date
    /// Their shelf in figures, the books they keep to themselves left out.
    var favoriteCount = 0
    var readingCount = 0
    var toReadCount = 0
    /// The book they started most recently.
    var readingTitle: String?

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
            favoriteCount: shelf.favorites.count + shelf.favoriteSagas.count,
            readingCount: shelf.reading.count,
            toReadCount: shelf.pile.count,
            // Most recently active first, as the friends list picks it.
            readingTitle: shelf.reading.first?.book.title
        )
    }
}

/// A book on a friend's shelf, and whether the reader already owns the story —
/// same title and first author, whatever the edition.
struct FriendBook: Identifiable, Hashable, Sendable {
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
struct FriendSaga: Identifiable, Sendable {
    let id: String
    /// The saga alone, whatever the language: what its page opens on.
    let seriesId: String
    let name: String
    let author: String?
    let language: BookLanguage?
    let ownedCount: Int
    /// Hearted by its owner. It then stands for its volumes among the
    /// favourites, which do not list them again one by one.
    let favorite: Bool
    /// When its owner hearted it. Nil on a saga not hearted, and on a heart
    /// given before the date was kept.
    var favoritedAt: Date?
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
struct FriendProfile: Sendable {
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
    /// How many books their library shows, the dropped ones aside.
    var bookCount = 0

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

    /// The hearted books, the one touched last first.
    var favoritesByActivity: [FriendBook] {
        favorites.sorted { ($0.lastActivityAt ?? .distantPast) > ($1.lastActivityAt ?? .distantPast) }
    }

    /// What moved on the shelf in the last thirty days, one line of each
    /// kind at most and each only when it is recent: the book in progress
    /// touched last, the last book finished, the saga hearted last. What a
    /// friend coming back looks for, rather than the same lists as last time.
    func recentActivity(now: Date = .now) -> [RecentActivity] {
        let since = now.addingTimeInterval(-RecentActivity.window)
        let reading = self.reading.first.flatMap { entry in
            entry.lastActivityAt.map { RecentActivity.reading(entry, at: $0) }
        }
        let finished = lastFinished.flatMap { entry in
            entry.book.finishedAt.map { RecentActivity.finished(entry, at: $0) }
        }
        let saga = favoriteSagas.first.flatMap { saga in
            saga.favoritedAt.map { RecentActivity.heartedSaga(saga, at: $0) }
        }
        return [reading, finished, saga].compactMap(\.self).filter { $0.date >= since }
    }

    /// The saga a book belongs to, when it carries its covers: the recent
    /// activity draws it under the book. The edition in the book's language
    /// first, a saga being filed per language.
    func saga(of book: Book) -> FriendSaga? {
        guard let seriesId = book.series?.id else { return nil }
        let candidates = sagas.filter { $0.seriesId == seriesId && !$0.volumes.isEmpty }
        return candidates.first { $0.language == book.language } ?? candidates.first
    }

    var displayName: String {
        firstName ?? String(localized: "Un lecteur")
    }

    var isEmpty: Bool {
        reading.isEmpty && pile.isEmpty && favorites.isEmpty && sagas.isEmpty && bookCount == 0
    }
}

/// One thing that moved on a shelf lately, with its day: a book picked up or
/// read on, the last book finished, a saga hearted.
enum RecentActivity: Identifiable, Sendable {
    case reading(FriendBook, at: Date)
    case finished(FriendBook, at: Date)
    case heartedSaga(FriendSaga, at: Date)

    /// How far back "lately" goes.
    static let window: TimeInterval = 30 * 24 * 3600

    var id: String {
        switch self {
        case .reading: "reading-\(subjectId)"
        case .finished: "finished-\(subjectId)"
        case .heartedSaga: "saga-\(subjectId)"
        }
    }

    /// The book or saga it is about.
    var subjectId: String {
        switch self {
        case let .reading(entry, _), let .finished(entry, _): entry.id
        case let .heartedSaga(saga, _): saga.id
        }
    }

    var date: Date {
        switch self {
        case let .reading(_, date), let .finished(_, date), let .heartedSaga(_, date): date
        }
    }

    /// The book it opens on, a saga opening nothing.
    var book: FriendBook? {
        switch self {
        case let .reading(entry, _), let .finished(entry, _): entry
        case .heartedSaga: nil
        }
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
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.FriendsQuery()
        )
        return data.friends.map { Friend(row: $0.fragments.friendRow) }
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
        favorite: Bool,
        after: String?
    ) async throws -> (sagas: [FriendSaga], hasMore: Bool) {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.FriendSagaPageQuery(
                userId: friendId,
                state: GraphQLHelpers.graphQLNullable(state.map { .case(SeriesAPI.graphQLState($0)) }),
                favorite: favorite ? .some(true) : .none,
                after: GraphQLHelpers.graphQLNullable(after)
            )
        )
        guard let page = data.friendSagaPage else { return ([], false) }
        return (page.sagas.map { FriendSaga(row: $0.fragments.friendSagaRow) }, page.hasMore)
    }

    /// One book of a friend's shelf, with everything the read-only page shows.
    /// Nil for a book they keep to themselves, and for anybody who is not a
    /// friend.
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
        return friendBook
    }

    /// Put a friend's book on the reader's shelf. The server copies it from the
    /// friend's record and names them as who recommended it.
    @discardableResult
    static func addBook(friendId: String, bookId: String, status: CopiedStatus) async throws -> String {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.AddFriendBookMutation(
                userId: friendId,
                bookId: bookId,
                status: .case(status.graphQL)
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
            favoriteCount: row.favoriteCount,
            readingCount: row.readingCount,
            toReadCount: row.toReadCount,
            readingTitle: row.readingTitle
        )
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
            bookCount: shelf.bookCount
        )
    }
}

private extension FriendSaga {
    init(row: ShioriGraphQL.FriendSagaRow) {
        self.init(
            id: row.id,
            seriesId: row.seriesId,
            name: row.name,
            author: row.author,
            language: row.language?.asDomain,
            ownedCount: row.ownedCount,
            favorite: row.favorite,
            favoritedAt: row.favoritedAt.flatMap(GraphQLHelpers.parseISO8601),
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
            finishedAt: row.finishedAt.flatMap(GraphQLHelpers.parseISO8601),
            shelvedAt: GraphQLHelpers.parseISO8601(row.shelvedAt)
        )
    }
}
