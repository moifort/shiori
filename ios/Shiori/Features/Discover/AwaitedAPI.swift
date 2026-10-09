import Apollo
import ApolloAPI
import Foundation
import SwiftUI

extension Notification.Name {
    /// An edition was awaited or no longer is: Découvrir's strip and a book's
    /// page redraw. Apart from the library's own notice, which would reload
    /// every list for a change none of them shows.
    static let shioriAwaitedEditionsDidChange = Notification.Name("ShioriAwaitedEditionsDidChange")
}

/// Where an edition the reader awaits stands.
enum AwaitedState: String, Codable, Sendable, Hashable {
    /// The web has found nothing of it yet.
    case unannounced
    /// Found, but not out: announced for a date, or for none yet.
    case announced
    /// Out: a printed edition past its date, a recording once Audible
    /// confirmed it.
    case available
}

/// A book the reader waits to see come out in the language of their app, in
/// one format: translated into print, or recorded. The server searches the web
/// for it once a week and pushes an alert the day it is out; it stops being
/// awaited on its own once the library holds it — the Audible sync bringing it
/// in, or the reader adding it.
struct AwaitedEdition: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let format: ReleaseFormat
    let state: AwaitedState
    /// Its title in the language awaited once found, else the original's.
    let title: String
    let originalTitle: String
    let originalLanguage: BookLanguage?
    let authors: [String]
    /// `YYYY`, `YYYY-MM` or `YYYY-MM-DD`. Nil until found, and for an edition
    /// announced with no date.
    let date: String?
    let coverURL: URL?
    /// Where to get it: the recording on Audible, the printed edition on
    /// Amazon. Nil until a store confirmed it.
    let storeURL: URL?
    /// When the reader started awaiting it.
    let awaitedAt: Date?
    /// The book it was awaited from, on its owner's shelf. Nil for one awaited
    /// from a scan's review without being added.
    let bookId: String?
    /// The reader's own id for their copy, a friend's for theirs.
    let ownerId: String

    /// Under a cover, in a strip: out, when it comes, or that nothing is
    /// announced.
    var caption: String {
        switch state {
        case .available: String(localized: "Disponible")
        case .announced: date.map(ReleaseDateText.short) ?? String(localized: "Annoncé")
        case .unannounced: String(localized: "Pas annoncé")
        }
    }

    /// Under a title, in a row: where it stands, in a sentence.
    var stateLine: String {
        switch state {
        case .available:
            date.map { String(localized: "Sorti \(ReleaseDateText.phrase($0))") }
                ?? String(localized: "Disponible")
        case .announced:
            date.map(ReleaseDateText.coming) ?? String(localized: "Annoncé, sans date")
        case .unannounced:
            String(localized: "Pas encore annoncé")
        }
    }

    /// Green once out, orange while announced — as Découvrir draws what is
    /// coming — and the secondary grey while nothing is.
    var stateTint: Color? {
        switch state {
        case .available: .green
        case .announced: .orange
        case .unannounced: nil
        }
    }

    /// Drawn as the Books tab draws a book, the headphones on a recording's
    /// cover.
    var cover: Book {
        Book(
            id: "awaited-\(id)",
            title: title,
            authors: authors,
            format: format == .audiobook ? .audiobook : .book,
            coverURL: coverURL,
            status: .toRead
        )
    }
}

/// What a book's page offers to await: its edition in the app's language, in
/// each format it may be awaited in, and the ones already awaited.
struct EditionOffer: Sendable, Equatable {
    var formats: [ReleaseFormat] = []
    var awaited: [AwaitedEdition] = []

    /// The formats not awaited yet: what the page's actions offer.
    var awaitable: [ReleaseFormat] {
        formats.filter { format in !awaited.contains { $0.format == format } }
    }
}

extension AwaitedEdition {
    /// What a page shows the moment the reader asks to await an edition, while
    /// the server looks it up on the web behind their back: nothing announced
    /// yet. The server's answer replaces it.
    static func pending(format: ReleaseFormat, of book: Book) -> AwaitedEdition {
        AwaitedEdition(
            id: "pending-\(book.id)-\(format.rawValue)",
            format: format,
            state: .unannounced,
            title: book.title,
            originalTitle: book.title,
            originalLanguage: nil,
            authors: book.authors,
            date: nil,
            coverURL: nil,
            storeURL: nil,
            awaitedAt: .now,
            bookId: book.id,
            ownerId: ""
        )
    }
}

extension ReleaseFormat {
    /// The action that awaits a book's edition in this format.
    var awaitLabel: String {
        switch self {
        case .book: String(localized: "Guetter la version française du livre")
        case .audiobook: String(localized: "Guetter la version française audio")
        }
    }

    /// The format an edition is awaited in, over its title on a book's page.
    var awaitedTitle: String {
        switch self {
        case .book: String(localized: "Bientôt en FR")
        case .audiobook: String(localized: "Bientôt en audio")
        }
    }

    /// The store an edition out in this format is sold in, on its tag.
    var storeName: String {
        switch self {
        case .book: "Amazon"
        case .audiobook: "Audible"
        }
    }

    /// The colour of that store's tag: Audible's orange, the neutral grey for
    /// Amazon.
    var storeTint: Color? {
        switch self {
        case .book: nil
        case .audiobook: .audible
        }
    }

    /// The action that opens where an edition out in this format is sold.
    var storeLabel: String {
        switch self {
        case .book: String(localized: "Voir sur Amazon")
        case .audiobook: String(localized: "Ouvrir dans Audible")
        }
    }
}

enum AwaitedAPI {
    /// Awaiting looks the edition up on the web at once when nobody did: a
    /// grounded call, given what a saga's first look is given.
    private static let awaitTimeout: TimeInterval = 60

    static func awaited(format: ReleaseFormat) async throws -> [AwaitedEdition] {
        #if DEBUG
        if Showcase.isOn {
            return []
        }
        #endif
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.AwaitedEditionsQuery(format: .case(format.graphQL))
        )
        return data.awaitedEditions.map { AwaitedEdition(fields: $0.fragments.awaitedEditionFields) }
    }

    /// What the page of one of the reader's own books offers. Nil for a book
    /// that is no longer theirs.
    static func offer(bookId: String) async throws -> EditionOffer? {
        #if DEBUG
        if Showcase.isOn {
            return nil
        }
        #endif
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.BookEditionOfferQuery(bookId: bookId)
        )
        return data.bookEditionOffer.map { EditionOffer(fields: $0.fragments.editionOfferFields) }
    }

    /// The formats a book not added yet — the one a scan proposes — may be
    /// awaited in once added.
    static func formats(language: BookLanguage, format: BookFormat) async throws -> [ReleaseFormat] {
        #if DEBUG
        if Showcase.isOn {
            return []
        }
        #endif
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.DraftEditionFormatsQuery(
                language: LibraryAPI.graphQLLanguage(language),
                format: LibraryAPI.graphQLFormat(format)
            )
        )
        return data.draftEditionFormats.compactMap { format -> ReleaseFormat? in
            switch format.value {
            case .book: return .book
            case .audiobook: return .audiobook
            case nil: return nil
            }
        }
    }

    /// What the page of a friend's book offers. Nil for a book that is not
    /// shared with the reader.
    static func offer(friendId: String, bookId: String) async throws -> EditionOffer? {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.FriendBookEditionOfferQuery(userId: friendId, bookId: bookId)
        )
        return data.friendBookEditionOffer.map { EditionOffer(fields: $0.fragments.editionOfferFields) }
    }

    static func awaitEdition(bookId: String, format: ReleaseFormat) async throws -> AwaitedEdition {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.AwaitBookEditionMutation(
                bookId: bookId,
                format: .case(format.graphQL)
            ),
            requestTimeout: awaitTimeout,
            changesLibrary: false
        )
        await announce()
        return AwaitedEdition(fields: data.awaitBookEdition.fragments.awaitedEditionFields)
    }

    static func awaitEdition(
        friendId: String,
        bookId: String,
        format: ReleaseFormat
    ) async throws -> AwaitedEdition {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.AwaitFriendBookEditionMutation(
                userId: friendId,
                bookId: bookId,
                format: .case(format.graphQL)
            ),
            requestTimeout: awaitTimeout,
            changesLibrary: false
        )
        await announce()
        return AwaitedEdition(fields: data.awaitFriendBookEdition.fragments.awaitedEditionFields)
    }

    /// Awaits a book a scan proposed, from its review, without adding it to
    /// the library.
    static func awaitScanned(_ draft: BookDraft, format: ReleaseFormat) async throws -> AwaitedEdition {
        let book = ShioriGraphQL.ScannedBookInput(
            authors: GraphQLHelpers.graphQLNullable(draft.authors.isEmpty ? nil : draft.authors),
            coverUrl: GraphQLHelpers.graphQLNullable(draft.coverURL?.absoluteString),
            format: LibraryAPI.graphQLFormat(draft.format),
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
            mutation: ShioriGraphQL.AwaitScannedEditionMutation(book: book, format: .case(format.graphQL)),
            requestTimeout: awaitTimeout,
            changesLibrary: false
        )
        await announce()
        return AwaitedEdition(fields: data.awaitScannedEdition.fragments.awaitedEditionFields)
    }

    static func stop(id: String) async throws {
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.StopAwaitingEditionMutation(id: id),
            changesLibrary: false
        )
        await announce()
    }

    private static func announce() async {
        await MainActor.run {
            NotificationCenter.default.post(name: .shioriAwaitedEditionsDidChange, object: nil)
        }
    }
}

extension AwaitedEdition {
    init(fields: ShioriGraphQL.AwaitedEditionFields) {
        let state: AwaitedState = switch fields.state.value {
        case .available: .available
        case .announced: .announced
        case .unannounced, nil: .unannounced
        }
        self.init(
            id: fields.id,
            format: fields.format.value == .audiobook ? .audiobook : .book,
            state: state,
            title: fields.title,
            originalTitle: fields.originalTitle,
            originalLanguage: fields.originalLanguage.asDomain,
            authors: fields.authors,
            date: fields.date,
            coverURL: fields.coverUrl.flatMap(URL.init(string:)),
            storeURL: fields.storeUrl.flatMap(URL.init(string:)),
            awaitedAt: GraphQLHelpers.parseISO8601(fields.awaitedAt),
            bookId: fields.sourceBookId,
            ownerId: fields.ownerId
        )
    }
}

private extension EditionOffer {
    init(fields: ShioriGraphQL.EditionOfferFields) {
        self.init(
            formats: fields.formats.compactMap { format -> ReleaseFormat? in
                switch format.value {
                case .book: return .book
                case .audiobook: return .audiobook
                case nil: return nil
                }
            },
            awaited: fields.awaited.map { AwaitedEdition(fields: $0.fragments.awaitedEditionFields) }
        )
    }
}
