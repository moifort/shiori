import Foundation

/// A book the Découvrir tab proposes, with the line that says why.
struct Suggestion: Identifiable, Hashable, Sendable {
    /// What `dismiss` and `add` name it by.
    let key: String
    var id: String { key }
    let book: Book
    let reason: String
    let award: String?
    let publicRating: Double?
    let ratingCount: Int?
    /// `YYYY`, `YYYY-MM` or `YYYY-MM-DD`.
    let releaseDate: String?
}

/// A book coming out that the reader has a reason to care about.
struct Release: Identifiable, Hashable, Sendable {
    let key: String
    var id: String { key }
    let kind: AlertKind
    /// `YYYY`, `YYYY-MM` or `YYYY-MM-DD`.
    let date: String
    let suggestion: Suggestion
}

struct LovedShelf: Identifiable, Hashable, Sendable {
    let anchor: String
    var id: String { anchor }
    let items: [Suggestion]
}

/// A book a friend hearted that the reader does not own. Opens as the friend's
/// copy.
struct FriendFavorite: Identifiable, Hashable, Sendable {
    let key: String
    var id: String { key }
    let friendId: String
    let bookId: String
    let friendNames: [String]
    let book: Book
}

struct DiscoverFeed: Sendable {
    var preparedAt: Date?
    var canRefresh: Bool
    var friendsFavorites: [FriendFavorite]
    var audible: [Suggestion]
    var releases: [Release]
    var becauseYouLoved: [LovedShelf]
    var awards: [Suggestion]
    var acclaimed: [Suggestion]
    var offTrail: [Suggestion]

    /// Nothing to show at all: before the first preparation, for a reader with
    /// no friend hearting anything.
    var isEmpty: Bool {
        friendsFavorites.isEmpty && audible.isEmpty && releases.isEmpty && becauseYouLoved.isEmpty
            && awards.isEmpty && acclaimed.isEmpty && offTrail.isEmpty
    }

    /// Forget a suggestion wherever it sits, once dismissed or taken.
    mutating func remove(key: String) {
        friendsFavorites.removeAll { $0.key == key }
        audible.removeAll { $0.key == key }
        releases.removeAll { $0.key == key || $0.suggestion.key == key }
        becauseYouLoved = becauseYouLoved
            .map { LovedShelf(anchor: $0.anchor, items: $0.items.filter { $0.key != key }) }
            .filter { !$0.items.isEmpty }
        awards.removeAll { $0.key == key }
        acclaimed.removeAll { $0.key == key }
        offTrail.removeAll { $0.key == key }
    }
}

enum DiscoverAPI {
    /// Preparing the shelves runs several web-searching model calls: the
    /// request is given the server's whole ceiling plus a margin.
    private static let refreshTimeout: TimeInterval = 200

    static func feed() async throws -> DiscoverFeed {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.DiscoverQuery()
        )
        return DiscoverFeed(fields: data.discover.fragments.discoverFields)
    }

    static func refresh() async throws -> DiscoverFeed {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.RefreshDiscoverMutation(),
            requestTimeout: refreshTimeout,
            changesLibrary: false
        )
        return DiscoverFeed(fields: data.refreshDiscover.fragments.discoverFields)
    }

    static func dismiss(key: String) async throws {
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.DismissSuggestionMutation(key: key),
            changesLibrary: false
        )
    }

    @discardableResult
    static func add(key: String, status: CopiedStatus) async throws -> String {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.AddSuggestionMutation(key: key, status: .case(status.graphQL))
        )
        return data.addSuggestion.id
    }
}

private extension DiscoverFeed {
    init(fields: ShioriGraphQL.DiscoverFields) {
        self.init(
            preparedAt: fields.preparedAt.flatMap(GraphQLHelpers.parseISO8601),
            canRefresh: fields.canRefresh,
            friendsFavorites: fields.friendsFavorites.map { favorite in
                FriendFavorite(
                    key: favorite.key,
                    friendId: favorite.friendId,
                    bookId: favorite.bookId,
                    friendNames: favorite.friendNames,
                    book: Book(
                        id: favorite.bookId,
                        title: favorite.title,
                        authors: favorite.authors,
                        format: favorite.format.asDomain,
                        series: favorite.seriesName.map {
                            SeriesMembership(id: $0, name: $0, volume: favorite.volume, kind: .main)
                        },
                        coverURL: favorite.coverUrl.flatMap(URL.init(string:)),
                        status: .toRead
                    )
                )
            },
            audible: fields.audible.map { Suggestion(fields: $0.fragments.suggestionFields) },
            releases: fields.releases.compactMap { release in
                guard let kind = release.kind.value.flatMap(AlertKind.init(graphQL:)) else { return nil }
                return Release(
                    key: release.key,
                    kind: kind,
                    date: release.date,
                    suggestion: Suggestion(fields: release.suggestion.fragments.suggestionFields)
                )
            },
            becauseYouLoved: fields.becauseYouLoved.map { shelf in
                LovedShelf(
                    anchor: shelf.anchor,
                    items: shelf.items.map { Suggestion(fields: $0.fragments.suggestionFields) }
                )
            },
            awards: fields.awards.map { Suggestion(fields: $0.fragments.suggestionFields) },
            acclaimed: fields.acclaimed.map { Suggestion(fields: $0.fragments.suggestionFields) },
            offTrail: fields.offTrail.map { Suggestion(fields: $0.fragments.suggestionFields) }
        )
    }
}

private extension Suggestion {
    init(fields: ShioriGraphQL.SuggestionFields) {
        self.init(
            key: fields.key,
            book: Book(
                id: fields.key,
                title: fields.title,
                authors: fields.authors,
                format: fields.format.asDomain,
                firstPublishedIn: fields.firstPublishedIn,
                synopsis: fields.synopsis,
                genre: fields.genre?.asDomain,
                language: fields.language?.asDomain,
                series: fields.seriesName.map {
                    SeriesMembership(id: $0, name: $0, volume: fields.volume, kind: .main)
                },
                coverURL: fields.coverUrl.flatMap(URL.init(string:)),
                status: .toRead
            ),
            reason: fields.reason,
            award: fields.award,
            publicRating: fields.publicRating,
            ratingCount: fields.ratingCount,
            releaseDate: fields.releaseDate
        )
    }
}
