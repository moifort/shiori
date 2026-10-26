import Foundation
import SwiftUI

/// One of the reader's own books a suggestion was drawn from, with how it
/// ranks for them: its heart or stars, or its saga's when it has none.
struct SuggestionReference: Identifiable, Hashable, Sendable, Codable {
    let bookId: String
    let seriesId: String?
    /// The saga's name when a saga was cited, else the book's title.
    let title: String
    let favorite: Bool
    let rating: Double?
    let viaSeries: Bool
    var coverURL: URL?
    /// The reason cites the saga by name: the reference opens the saga's
    /// page rather than its first volume's.
    var citesSaga = false

    var id: String { bookId }

    /// Drawn as the reader's own book, its cover theirs.
    var cover: Book {
        Book(id: bookId, title: title, authors: [], coverURL: coverURL, status: .read)
    }
}

/// Why the reader turned a suggestion down, told to the model next month:
/// not for now, or not their kind of book.
enum DismissalReason: Hashable, Sendable {
    /// "Pas intéressé": the model only leaves it out.
    case notInterested
    /// "Je n'aime pas": the model steers clear of its like.
    case disliked
}

/// A book Claude chose for the reader from their hearts and stars, with why,
/// as its edition stands in one format and the app's language.
struct Suggestion: Identifiable, Hashable, Sendable, Codable {
    let id: String
    let format: ReleaseFormat
    /// Its title in the app's language: the edition's once found, else the
    /// model's.
    let title: String
    let originalTitle: String
    let originalLanguage: BookLanguage?
    let authors: [String]
    /// Why, in one sentence citing a book of the reader's.
    let reason: String
    /// "comme Gagner la guerre".
    let short: String
    let references: [SuggestionReference]
    let state: AwaitedState
    let watched: Bool
    let date: String?
    let coverURL: URL?
    let storeURL: URL?
    let awaitableFormats: [ReleaseFormat]
    let awaitedEditionId: String?

    /// The reference the row's mark is drawn from: the first the reason cites.
    var leadReference: SuggestionReference? { references.first }

    /// Drawn as the Books tab draws a book, the headphones on a recording's
    /// cover.
    var cover: Book {
        Book(
            id: "suggestion-\(id)",
            title: title,
            authors: authors,
            format: format == .audiobook ? .audiobook : .book,
            coverURL: coverURL,
            status: .toRead
        )
    }

    /// What adding it or awaiting it sends: the original title, in the
    /// language it was written in, so the server finds the watch it is read
    /// off.
    var draft: BookDraft {
        var draft = BookDraft(title: originalTitle, authors: authors)
        draft.format = .book
        draft.language = originalLanguage
        return draft
    }

    /// Under its author on its page: where the edition stands, once a reader
    /// awaited it and it was looked up.
    var stateLine: String {
        switch state {
        case .available:
            String(localized: "Disponible")
        case .announced:
            date.map(ReleaseDateText.coming) ?? String(localized: "Annoncé, sans date")
        case .unannounced:
            if format == .audiobook { String(localized: "Pas encore en audio") }
            else { String(localized: "Non traduit") }
        }
    }

    var stateTint: Color {
        switch state {
        case .available: .green
        case .announced: .orange
        case .unannounced: .gray
        }
    }

    /// What the model is told when the page describes it: the edition in the
    /// app's language when found, else the book as written.
    var seed: ReleaseSeed {
        ReleaseSeed(
            title: title,
            authors: authors,
            format: format == .audiobook ? .audiobook : .book,
            language: state == .unannounced ? originalLanguage : nil,
            releasedOn: date,
            coverURL: coverURL
        )
    }
}

/// The month's discoveries: the month the line is titled after and its
/// suggestions, three at most.
struct MonthlyDiscoveries: Hashable, Sendable, Codable {
    /// Where the month's selection stands.
    enum Status: String, Hashable, Sendable, Codable {
        /// Made for this month: its suggestions, or none once they ran out.
        case ready
        /// Being made by another look: ask again in a few seconds.
        case searching
        /// Not made for this month: Découvrir not opened yet, or it failed.
        case none
    }

    /// `YYYY-MM`.
    let month: String
    var status: Status = .ready
    let suggestions: [Suggestion]

    /// "Les découvertes d'octobre", "Les découvertes de novembre" — "October's
    /// discoveries" in English.
    var title: String { Self.title(month: month) }

    static func title(month: String, locale: Locale = .current) -> String {
        let name = monthName(month, locale: locale)
        return elided(name)
            ? String(localized: "Les découvertes d’\(name)")
            : String(localized: "Les découvertes de \(name)")
    }

    /// The home's hero while the month's selection is made: "Vos livres
    /// d'octobre arrivent", "Vos livres de novembre arrivent".
    static func arrivingTitle(month: String, locale: Locale = .current) -> String {
        let name = monthName(month, locale: locale)
        return elided(name)
            ? String(localized: "Vos livres d’\(name) arrivent")
            : String(localized: "Vos livres de \(name) arrivent")
    }

    /// Under the title once the month's selection ran out: that it did, and
    /// when the next ones come.
    var nextLine: String {
        String(localized: "Plus de découvertes ce mois-ci : prochaines en \(Self.monthName(Self.month(after: month))).")
    }

    /// The home's last page once the month's discoveries ran out: "Les
    /// prochaines arrivent en novembre".
    static func nextArrivalLine(month: String, locale: Locale = .current) -> String {
        String(localized: "Les prochaines arrivent en \(monthName(Self.month(after: month), locale: locale))")
    }

    /// `YYYY-MM` of the month a date falls in, in UTC as the server counts.
    static func month(of date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let parts = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", parts.year ?? 2026, parts.month ?? 1)
    }

    static func month(after month: String) -> String {
        let parts = month.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2 else { return month }
        let next = parts[1] == 12 ? (parts[0] + 1, 1) : (parts[0], parts[1] + 1)
        return String(format: "%04d-%02d", next.0, next.1)
    }

    private static func monthName(_ month: String, locale: Locale = .current) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(identifier: "UTC")
        parser.dateFormat = "yyyy-MM"
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.setLocalizedDateFormatFromTemplate("LLLL")
        return formatter.string(from: parser.date(from: month) ?? .now)
    }

    private static func elided(_ name: String) -> Bool {
        name.lowercased().first.map { "aeiouyéèh".contains($0) } ?? false
    }
}

enum SuggestionsAPI {
    /// The first look of a month waits for the model to choose, about a
    /// minute, and the catalogue checks after it.
    private static let requestTimeout: TimeInterval = 150

    /// `lookUp`, from Découvrir: a month with no selection yet gets one made.
    /// Without it — the home page — the stored selection is read.
    static func monthly(format: ReleaseFormat, lookUp: Bool) async throws -> MonthlyDiscoveries {
        #if DEBUG
        if Showcase.isOn {
            return Showcase.monthlyDiscoveries
        }
        #endif
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.MonthlyDiscoveriesQuery(format: .case(format.graphQL), lookUp: .some(lookUp)),
            requestTimeout: requestTimeout
        )
        let status: MonthlyDiscoveries.Status = switch data.monthlyDiscoveries.status.value {
        case .ready: .ready
        case .searching: .searching
        case .none?, nil: .none
        }
        return MonthlyDiscoveries(
            month: data.monthlyDiscoveries.month,
            status: status,
            suggestions: data.monthlyDiscoveries.suggestions.map {
                Suggestion(fields: $0.fragments.suggestionFields)
            }
        )
    }

    /// "Pas intéressé" or "Je n'aime pas": never suggested again.
    static func dismiss(id: String, reason: DismissalReason) async throws {
        let told: ShioriGraphQL.DismissalReason = switch reason {
        case .notInterested: .notInterested
        case .disliked: .disliked
        }
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.DismissSuggestionMutation(id: id, reason: .init(told)),
            changesLibrary: false
        )
    }
}

extension Suggestion {
    init(fields: ShioriGraphQL.SuggestionFields) {
        let state: AwaitedState = switch fields.state.value {
        case .available: .available
        case .announced: .announced
        case .unannounced, nil: .unannounced
        }
        self.init(
            id: fields.id,
            format: fields.format.value == .audiobook ? .audiobook : .book,
            title: fields.title,
            originalTitle: fields.originalTitle,
            originalLanguage: fields.originalLanguage.asDomain,
            authors: fields.authors,
            reason: fields.reason,
            short: fields.short,
            references: fields.references.map { reference in
                SuggestionReference(
                    bookId: reference.bookId,
                    seriesId: reference.seriesId,
                    title: reference.title,
                    favorite: reference.favorite,
                    rating: reference.rating,
                    viaSeries: reference.viaSeries,
                    coverURL: reference.coverUrl.flatMap(URL.init(string:)),
                    citesSaga: reference.citesSaga
                )
            },
            state: state,
            watched: fields.watched,
            date: fields.date,
            coverURL: fields.coverUrl.flatMap(URL.init(string:)),
            storeURL: fields.storeUrl.flatMap(URL.init(string:)),
            awaitableFormats: fields.awaitableFormats.compactMap { format -> ReleaseFormat? in
                switch format.value {
                case .book: return .book
                case .audiobook: return .audiobook
                case nil: return nil
                }
            },
            awaitedEditionId: fields.awaitedEditionId
        )
    }
}

extension MonthlyDiscoveries {
    /// Five suggestions drawn from the blind test of 2026-10-12, for the
    /// previews and the screenshot harness.
    static let preview = MonthlyDiscoveries(
        month: "2026-10",
        suggestions: [
            .sample(
                id: "lies", title: "Les Salauds Gentilshommes", original: "The Lies of Locke Lamora",
                author: "Scott Lynch", short: "comme Gagner la guerre",
                reason: "Un héros rusé et une narration brillante, avec le souffle de la Chronique du Tueur de Roi et la verve de Gagner la guerre.",
                references: [
                    SuggestionReference(bookId: "gagner", seriesId: nil, title: "Gagner la guerre", favorite: true, rating: 5, viaSeries: false),
                    SuggestionReference(bookId: "nom-du-vent", seriesId: "kingkiller", title: "Chronique du Tueur de Roi", favorite: false, rating: 4, viaSeries: true, citesSaga: true),
                ]
            ),
            .sample(
                id: "silo", title: "Silo", original: "Wool", author: "Hugh Howey", short: "comme Métro",
                reason: "Une société close et mystérieuse, dans la veine de Métro de Glukhovsky, avec une vraie tension à chaque chapitre.",
                references: [
                    SuggestionReference(bookId: "metro", seriesId: "metro", title: "Métro", favorite: false, rating: 4, viaSeries: true),
                ]
            ),
            .sample(
                id: "eiger", title: "La Sanction", original: "The Eiger Sanction", author: "Trevanian",
                short: "comme Shibumi",
                reason: "Un autre roman de Trevanian, après Shibumi : espionnage, alpinisme et ironie mordante.",
                references: [
                    SuggestionReference(bookId: "shibumi", seriesId: nil, title: "Shibumi", favorite: true, rating: 5, viaSeries: false),
                ]
            ),
            .sample(
                id: "dark-matter", title: "Dark Matter", original: "Dark Matter", author: "Blake Crouch",
                short: "comme Projet Dernière chance",
                reason: "Un thriller de science-fiction haletant et vertigineux, qui plaira au lecteur de Projet Dernière chance.",
                references: [
                    SuggestionReference(bookId: "hail-mary", seriesId: nil, title: "Projet Dernière chance", favorite: true, rating: 5, viaSeries: false),
                ]
            ),
            .sample(
                id: "fire-deep", title: "Un feu sur l’abîme", original: "A Fire Upon the Deep", author: "Vernor Vinge",
                short: "comme Dans la toile du temps",
                reason: "Un space opera aux idées audacieuses et aux extraterrestres inoubliables, proche de Dans la toile du temps.",
                references: [
                    SuggestionReference(bookId: "children-time", seriesId: "children-time", title: "Dans la toile du temps", favorite: true, rating: 5, viaSeries: true),
                ]
            ),
        ]
    )
}

extension Suggestion {
    static func sample(
        id: String,
        title: String,
        original: String,
        author: String,
        short: String,
        reason: String,
        references: [SuggestionReference]
    ) -> Suggestion {
        Suggestion(
            id: id, format: .book, title: title, originalTitle: original, originalLanguage: .en,
            authors: [author], reason: reason, short: short, references: references,
            state: .unannounced, watched: false, date: nil, coverURL: nil, storeURL: nil,
            awaitableFormats: [.book, .audiobook], awaitedEditionId: nil
        )
    }

    static var preview: Suggestion { MonthlyDiscoveries.preview.suggestions[0] }
}
