import Foundation

/// How a translation reaches the reader.
enum TranslationFormat: Sendable, Hashable {
    case book, audiobook

    var label: String {
        switch self {
        case .book: String(localized: "Livre")
        case .audiobook: String(localized: "Livre audio")
        }
    }

    var symbol: String {
        switch self {
        case .book: "book"
        case .audiobook: "headphones"
        }
    }
}

/// One edition of a work in the app's language, out or announced.
struct TranslatedEdition: Identifiable, Hashable, Sendable {
    let title: String
    let volume: Int?
    let format: TranslationFormat
    /// `YYYY`, `YYYY-MM` or `YYYY-MM-DD`. Nil for an edition out on a date
    /// nobody found.
    let date: String?
    /// The recording's page on the reader's own Audible store.
    let audibleURL: URL?

    var id: String { "\(format)-\(volume.map(String.init) ?? title)" }

    /// Whether it is still to come: a day after today, or a month or a year
    /// not over yet — the server's rule, read on the phone's calendar.
    var isUpcoming: Bool {
        guard let date else { return false }
        let today = Date.now.formatted(.iso8601.year().month().day())
        return date.count == 10 ? date > today : String(today.prefix(date.count)) <= date
    }
}

/// A saga or a book the reader read in another language, with what exists or
/// is announced of it in the app's language.
struct Translation: Identifiable, Hashable, Sendable {
    let key: String
    var id: String { key }
    let isSeries: Bool
    let title: String
    let originalTitle: String
    let author: String?
    let originalLanguage: BookLanguage
    let volumesRead: [Int]
    let coverURL: URL?
    let nextDate: String?
    let editions: [TranslatedEdition]

    /// What the cover component draws.
    var book: Book {
        Book(
            id: key,
            title: title,
            authors: author.map { [$0] } ?? [],
            format: .book,
            coverURL: coverURL,
            status: .toRead
        )
    }

    var formats: [TranslationFormat] {
        [.book, .audiobook].filter { format in editions.contains { $0.format == format } }
    }
}

struct DiscoverFeed: Sendable {
    var preparedAt: Date?
    var canRefresh: Bool
    var upcoming: [Translation]
    var available: [Translation]

    var isEmpty: Bool { upcoming.isEmpty && available.isEmpty }

    mutating func remove(key: String) {
        upcoming.removeAll { $0.key == key }
        available.removeAll { $0.key == key }
    }
}

enum DiscoverAPI {
    /// A look runs web-searching model calls and an Audible search per
    /// author: the request is given the server's whole ceiling plus a margin.
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

    /// "Pas intéressé": the work never comes back, nor its alerts.
    static func dismiss(key: String) async throws {
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.DismissTranslationMutation(key: key),
            changesLibrary: false
        )
    }
}

private extension DiscoverFeed {
    init(fields: ShioriGraphQL.DiscoverFields) {
        self.init(
            preparedAt: fields.preparedAt.flatMap(GraphQLHelpers.parseISO8601),
            canRefresh: fields.canRefresh,
            upcoming: fields.upcoming.compactMap { Translation(fields: $0.fragments.translationFields) },
            available: fields.available.compactMap { Translation(fields: $0.fragments.translationFields) }
        )
    }
}

private extension Translation {
    init?(fields: ShioriGraphQL.TranslationFields) {
        guard let language = fields.originalLanguage.value?.asDomain else { return nil }
        self.init(
            key: fields.key,
            isSeries: fields.kind.value == .series,
            title: fields.title,
            originalTitle: fields.originalTitle,
            author: fields.author,
            originalLanguage: language,
            volumesRead: fields.volumesRead,
            coverURL: fields.coverUrl.flatMap(URL.init(string:)),
            nextDate: fields.nextDate,
            editions: fields.editions.map { edition in
                TranslatedEdition(
                    title: edition.title,
                    volume: edition.volume,
                    format: edition.format.value == .audiobook ? .audiobook : .book,
                    date: edition.date,
                    audibleURL: edition.audibleUrl.flatMap(URL.init(string:))
                )
            }
        )
    }
}
