import Apollo
import ApolloAPI
import Foundation
import SwiftUI

/// A literary award whose novel winners Découvrir lists. Its raw value is the
/// one the server spells it with, so a new award the server adds is skipped
/// rather than misread.
enum LiteraryAward: String, Sendable, Hashable, Identifiable {
    case hugo = "HUGO"
    case nebula = "NEBULA"
    case locusScienceFiction = "LOCUS_SF"
    case locusFantasy = "LOCUS_FANTASY"
    case clarke = "CLARKE"
    case worldFantasy = "WORLD_FANTASY"

    var id: String { rawValue }

    /// Its name in full, as a list's header says it.
    var name: String {
        switch self {
        case .hugo: String(localized: "Prix Hugo")
        case .nebula: String(localized: "Prix Nebula")
        case .locusScienceFiction: String(localized: "Prix Locus de la science-fiction")
        case .locusFantasy: String(localized: "Prix Locus de la fantasy")
        case .clarke: String(localized: "Prix Arthur C. Clarke")
        case .worldFantasy: String(localized: "World Fantasy Award")
        }
    }

    /// Its name in a word, under a cover.
    var shortName: String {
        switch self {
        case .hugo: "Hugo"
        case .nebula: "Nebula"
        case .locusScienceFiction, .locusFantasy: "Locus"
        case .clarke: "Clarke"
        case .worldFantasy: "World Fantasy"
        }
    }
}

/// One prize a novel won, and the year it was presented.
struct AwardMention: Hashable, Sendable {
    let award: LiteraryAward
    let year: Int
}

/// A novel an award crowned, as its edition stands in one format and the
/// language of the app: out, announced, or not found — not found also while
/// nobody awaited it, so it was never looked up, which `watched` tells apart.
struct AwardWinner: Identifiable, Hashable, Sendable {
    let id: String
    let format: ReleaseFormat
    /// Its title in the app's language once found, else the one it won under.
    let title: String
    let originalTitle: String
    let originalLanguage: BookLanguage?
    let authors: [String]
    /// Newest first.
    let mentions: [AwardMention]
    let state: AwaitedState
    let watched: Bool
    let date: String?
    let coverURL: URL?
    let storeURL: URL?
    /// Whether "Guetter" is offered: not out, not awaited yet, and a format
    /// its edition can be awaited in.
    let awaitable: Bool
    let awaitedEditionId: String?

    /// Under its cover in the strip: the latest prize and its year.
    var caption: String {
        mentions.first.map { "\($0.award.shortName) \($0.year)" } ?? ""
    }

    /// Where its edition stands, in a sentence, for its page.
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

    /// Every prize it won, named in full, in a line above its page:
    /// "Prix Hugo 2026 · Prix Locus de la fantasy 2026".
    var awardsLine: String {
        mentions.map { "\($0.award.name) \($0.year)" }.joined(separator: " · ")
    }

    /// Every prize it won, in a line: "Hugo 1990 · Locus 1990".
    var mentionsLine: String {
        mentions.map { "\($0.award.shortName) \($0.year)" }.joined(separator: " · ")
    }

    /// Drawn as the Books tab draws a book, the headphones on a recording's
    /// cover.
    var cover: Book {
        Book(
            id: "award-\(id)",
            title: title,
            authors: authors,
            format: format == .audiobook ? .audiobook : .book,
            coverURL: coverURL,
            status: .toRead
        )
    }

    /// What adding it to the pile or awaiting it sends: the title it won
    /// under, in the language it won in, so the server finds the watch the
    /// list is read off.
    var draft: BookDraft {
        var draft = BookDraft(title: originalTitle, authors: authors)
        draft.format = .book
        draft.language = originalLanguage
        return draft
    }
}

extension [AwardWinner] {
    /// The latest prize first, whatever order the server sent: the strip reads
    /// from this year's winner back. Two of a year keep the server's order.
    var latestFirst: [AwardWinner] {
        sorted { ($0.mentions.first?.year ?? 0) > ($1.mentions.first?.year ?? 0) }
    }
}

/// One genre's section of Découvrir's award winners: the latest its awards
/// crowned that the reader does not hold, none drawn in another section.
struct AwardSection: Identifiable, Hashable, Sendable {
    let genre: BookGenre
    let winners: [AwardWinner]

    var id: String { "\(genre)" }
}

enum AwardsAPI {
    /// One section per genre the reader reads most, the most read first.
    /// Empty when the reader reads no genre with awards enough.
    static func sections(format: ReleaseFormat) async throws -> [AwardSection] {
        #if DEBUG
        if Showcase.isOn {
            return []
        }
        #endif
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.AwardSectionsQuery(format: .case(format.graphQL))
        )
        return data.awardSections.map { section in
            AwardSection(
                genre: section.genre.asDomain,
                winners: section.winners
                    .map { AwardWinner(fields: $0.fragments.awardWinnerFields) }
                    .latestFirst
            )
        }
    }
}

extension AwardWinner {
    init(fields: ShioriGraphQL.AwardWinnerFields) {
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
            mentions: fields.awards.compactMap { mention in
                LiteraryAward(rawValue: mention.award.rawValue).map { AwardMention(award: $0, year: mention.year) }
            },
            state: state,
            watched: fields.watched,
            date: fields.date,
            coverURL: fields.coverUrl.flatMap(URL.init(string:)),
            storeURL: fields.storeUrl.flatMap(URL.init(string:)),
            awaitable: fields.awaitable,
            awaitedEditionId: fields.awaitedEditionId
        )
    }
}
