import Foundation

/// How a translation reaches the reader, and the filter the tab is read
/// through — kept between visits.
enum TranslationFormat: String, Sendable, Hashable, CaseIterable, Identifiable {
    case book, audiobook
    var id: String { rawValue }

    /// The toolbar's word for it: a recording is only ever offered from Audible.
    var filterLabel: String {
        switch self {
        case .book: String(localized: "Livre")
        case .audiobook: String(localized: "Audible")
        }
    }

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
    /// The edition's own cover, when its store showed one.
    var coverURL: URL? = nil

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

    /// Where the editions come from, as the row's tag says it: Audible for a
    /// recording its store lists.
    var source: (label: String, symbol: String)? {
        guard let format = editions.first?.format else { return nil }
        if format == .audiobook, editions.contains(where: { $0.audibleURL != nil }) {
            return (String(localized: "Audible"), format.symbol)
        }
        return (format.label, format.symbol)
    }

    /// The saga's volumes as the Series tab draws them: every one the reader
    /// read in the original or that exists in French, in order, each with its
    /// French edition when there is one.
    var strip: [(number: Int, edition: TranslatedEdition?)] {
        let numbers = Set(volumesRead).union(editions.compactMap(\.volume)).sorted()
        return numbers.map { number in (number, editions.first { $0.volume == number }) }
    }

    /// The work as one format shows it: only its editions in that format, and
    /// the soonest of those still to come. Nil when it has none.
    func narrowed(to format: TranslationFormat) -> Translation? {
        let kept = editions.filter { $0.format == format }
        guard !kept.isEmpty else { return nil }
        let next = kept.filter(\.isUpcoming).compactMap(\.date).min { ReleaseDateText.lastDay($0) < ReleaseDateText.lastDay($1) }
        return Translation(
            key: key, isSeries: isSeries, title: title, originalTitle: originalTitle, author: author,
            originalLanguage: originalLanguage, volumesRead: volumesRead, coverURL: coverURL,
            nextDate: next, editions: kept
        )
    }
}

struct DiscoverFeed: Sendable {
    var preparedAt: Date?
    var canRefresh: Bool
    var upcoming: [Translation]
    var available: [Translation]

    var isEmpty: Bool { upcoming.isEmpty && available.isEmpty }

    /// The tab through one format: a work moves to "coming soon" only for an
    /// edition of that format still to come, the soonest first.
    func narrowed(to format: TranslationFormat) -> DiscoverFeed {
        let works = (upcoming + available).compactMap { $0.narrowed(to: format) }
        return DiscoverFeed(
            preparedAt: preparedAt,
            canRefresh: canRefresh,
            upcoming: works.filter { $0.nextDate != nil }.sorted {
                ReleaseDateText.lastDay($0.nextDate ?? "") < ReleaseDateText.lastDay($1.nextDate ?? "")
            },
            available: works.filter { $0.nextDate == nil }
        )
    }

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
                    audibleURL: edition.audibleUrl.flatMap(URL.init(string:)),
                    coverURL: edition.coverUrl.flatMap(URL.init(string:))
                )
            }
        )
    }
}
