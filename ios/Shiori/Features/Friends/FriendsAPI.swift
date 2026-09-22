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

/// A book on a friend's shelf, and whether the reader already owns the story —
/// same title and first author, whatever the edition.
struct FriendBook: Identifiable, Hashable, Sendable {
    var id: String { book.id }
    var book: Book
    var inLibrary: Bool
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
    let name: String
    let author: String?
    let language: BookLanguage?
    let ownedCount: Int
    /// Hearted by its owner. It then stands for its volumes among the
    /// favourites, which do not list them again one by one.
    let favorite: Bool
    let genre: BookGenre?
    let subgenre: String?
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
    let sagas: [FriendSaga]

    var favoriteSagas: [FriendSaga] { sagas.filter(\.favorite) }

    var displayName: String {
        firstName ?? String(localized: "Un lecteur")
    }

    var isEmpty: Bool {
        reading.isEmpty && pile.isEmpty && favorites.isEmpty && sagas.isEmpty
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
            sagas: shelf.sagas.map {
                FriendSaga(
                    id: $0.id,
                    name: $0.name,
                    author: $0.author,
                    language: $0.language?.asDomain,
                    ownedCount: $0.ownedCount,
                    favorite: $0.favorite,
                    genre: $0.genre?.asDomain,
                    subgenre: $0.subgenre
                )
            }
        )
    }
}

private extension FriendBook {
    init(row: ShioriGraphQL.FriendBookRow) {
        self.init(book: Book(row: row), inLibrary: row.inLibrary)
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
            favorite: row.favorite
        )
    }
}
