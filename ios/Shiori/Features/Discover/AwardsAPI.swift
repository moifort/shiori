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
/// the server has not looked it up yet, which `watched` tells apart.
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
            if !watched { String(localized: "Recherche de l'édition en cours") }
            else if format == .audiobook { String(localized: "Pas encore en audio") }
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

/// One award's winners the reader does not hold, and how many of all of them
/// they have read.
struct AwardList: Identifiable, Hashable, Sendable {
    let award: LiteraryAward
    let readCount: Int
    let total: Int
    let winners: [AwardWinner]

    var id: String { award.id }
}

/// Découvrir's award winners: the genre shown, the others the reader reads
/// enough to switch to, the latest winners and every award in full.
struct AwardShelf: Identifiable, Hashable, Sendable {
    let genre: BookGenre
    let genres: [BookGenre]
    let recent: [AwardWinner]
    let awards: [AwardList]

    var id: String { "\(genre)" }
}

enum AwardsAPI {
    /// The winners of the genre asked for, else of the reader's own. Nil when
    /// the reader reads no genre with awards enough.
    static func shelf(format: ReleaseFormat, genre: BookGenre?) async throws -> AwardShelf? {
        #if DEBUG
        if Showcase.isOn {
            return nil
        }
        #endif
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.AwardShelfQuery(
                format: .case(format.graphQL),
                genre: GraphQLHelpers.graphQLNullable(genre.map(LibraryAPI.graphQLGenre))
            )
        )
        return data.awardShelf.map { shelf in
            AwardShelf(
                genre: shelf.genre.asDomain,
                genres: shelf.genres.map(\.asDomain),
                recent: shelf.recent.map { AwardWinner(fields: $0.fragments.awardWinnerFields) },
                awards: shelf.awards.compactMap { list in
                    guard let award = LiteraryAward(rawValue: list.award.rawValue) else { return nil }
                    return AwardList(
                        award: award,
                        readCount: list.readCount,
                        total: list.total,
                        winners: list.winners.map { AwardWinner(fields: $0.fragments.awardWinnerFields) }
                    )
                }
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
