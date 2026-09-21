import Foundation

/// Somebody the reader shares libraries with.
struct Friend: Identifiable, Sendable {
    var id: String { userId }
    let userId: String
    /// Nil for an account that never finished its onboarding.
    let firstName: String?
    let since: Date

    var displayName: String {
        firstName ?? String(localized: "Un lecteur")
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
}

/// A friend's shelf at a glance.
struct FriendProfile: Sendable {
    let userId: String
    let firstName: String?
    let reading: [Book]
    let pile: [Book]
    let favorites: [Book]
    let sagas: [FriendSaga]

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
        guard let profile = data.friendProfile else { return nil }
        return FriendProfile(
            userId: profile.userId,
            firstName: profile.firstName,
            reading: profile.reading.map { Book(row: $0.fragments.friendBookRow) },
            pile: profile.pile.map { Book(row: $0.fragments.friendBookRow) },
            favorites: profile.favorites.map { Book(row: $0.fragments.friendBookRow) },
            sagas: profile.sagas.map {
                FriendSaga(
                    id: $0.id,
                    name: $0.name,
                    author: $0.author,
                    language: $0.language?.asDomain,
                    ownedCount: $0.ownedCount
                )
            }
        )
    }

    static func invite() async throws -> FriendInvitation {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.InviteFriendMutation()
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
            mutation: ShioriGraphQL.AcceptFriendInvitationMutation(code: code)
        )
        return Friend(row: data.acceptFriendInvitation.fragments.friendRow)
    }

    @discardableResult
    static func remove(userId: String) async throws -> Bool {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.RemoveFriendMutation(userId: userId)
        )
        return data.removeFriend
    }
}

private extension Friend {
    init(row: ShioriGraphQL.FriendRow) {
        self.init(
            userId: row.userId,
            firstName: row.firstName,
            since: GraphQLHelpers.parseISO8601(row.since) ?? .now
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
