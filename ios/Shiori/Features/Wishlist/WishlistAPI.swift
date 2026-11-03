import Apollo
import ApolloAPI
import Foundation

extension Notification.Name {
    /// A book was wished for or no longer is: the wishlist and the pile's rail
    /// redraw. Apart from the library's own notice, which would reload every
    /// list for a change none of them shows.
    static let shioriWishlistDidChange = Notification.Name("ShioriWishlistDidChange")
}

enum WishlistAPI {
    static func wishlist() async throws -> Wishlist {
        #if DEBUG
        if Showcase.isOn {
            return .preview
        }
        #endif
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.WishlistQuery()
        )
        return Wishlist(
            wishes: data.wishlist.wishes.map { Wish(fields: $0.fragments.wishFields) },
            awaited: data.wishlist.awaited.map { AwaitedEdition(fields: $0.fragments.awaitedEditionFields) }
        )
    }

    /// Wishes for a book seen in Découvrir, among an award's winners or an
    /// author's works, or scanned and not added.
    @discardableResult
    static func wish(_ draft: BookDraft, origin: Wish.Origin, label: String? = nil) async throws -> Wish {
        let book = ShioriGraphQL.WishedBookInput(
            authors: GraphQLHelpers.graphQLNullable(draft.authors.isEmpty ? nil : draft.authors),
            coverUrl: GraphQLHelpers.graphQLNullable(draft.coverURL?.absoluteString),
            format: LibraryAPI.graphQLFormat(draft.format),
            isbn13: GraphQLHelpers.graphQLNullable(draft.isbn13),
            language: GraphQLHelpers.graphQLNullable(draft.language.map(LibraryAPI.graphQLLanguage)),
            series: GraphQLHelpers.graphQLNullable(
                draft.series.map { membership in
                    ShioriGraphQL.SeriesPlacementInput(
                        name: membership.name,
                        volume: GraphQLHelpers.graphQLNullable(membership.volume)
                    )
                }
            ),
            title: draft.title
        )
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.WishBookMutation(
                book: book,
                origin: .case(origin.graphQL),
                originLabel: GraphQLHelpers.graphQLNullable(label)
            ),
            changesLibrary: false
        )
        await announce()
        return Wish(fields: data.wishBook.fragments.wishFields)
    }

    /// Wishes for a book seen on a friend's shelf: the server re-reads it.
    @discardableResult
    static func wish(friendId: String, bookId: String) async throws -> Wish {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.WishFriendBookMutation(userId: friendId, bookId: bookId),
            changesLibrary: false
        )
        await announce()
        return Wish(fields: data.wishFriendBook.fragments.wishFields)
    }

    static func remove(id: String) async throws {
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.RemoveWishMutation(id: id),
            changesLibrary: false
        )
        await announce()
    }

    private static func announce() async {
        await MainActor.run {
            NotificationCenter.default.post(name: .shioriWishlistDidChange, object: nil)
        }
    }
}

extension Wish.Origin {
    var graphQL: ShioriGraphQL.WishOrigin {
        switch self {
        case .friend: .friend
        case .discovery: .discovery
        case .award: .award
        case .author: .author
        case .scan: .scan
        }
    }
}

private extension Wish {
    init(fields: ShioriGraphQL.WishFields) {
        let origin: Origin = switch fields.origin.value {
        case .friend: .friend
        case .award: .award
        case .author: .author
        case .scan: .scan
        case .discovery, nil: .discovery
        }
        self.init(
            id: fields.id,
            title: fields.title,
            authors: fields.authors,
            format: fields.format.value?.asDomain ?? .book,
            language: fields.language?.value?.asDomain,
            seriesName: fields.seriesName,
            volume: fields.volume,
            coverURL: fields.coverUrl.flatMap(URL.init(string:)),
            isbn13: fields.isbn13,
            origin: origin,
            originLabel: fields.originLabel,
            friendId: fields.friendId,
            wishedAt: GraphQLHelpers.parseISO8601(fields.wishedAt) ?? .now
        )
    }
}
