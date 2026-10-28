import Foundation

/// Why the pile offers a book, one section each, in the order the screen
/// draws them. Its raw value is the one the server spells it with, so a
/// section a newer server adds is skipped rather than misread.
enum PileSectionKind: String, Sendable, Hashable, Codable, CaseIterable {
    case toFinish = "TO_FINISH"
    case nextVolume = "NEXT_VOLUME"
    case recommended = "RECOMMENDED"
    case favoriteAuthors = "FAVORITE_AUTHORS"
    case favoriteNarrators = "FAVORITE_NARRATORS"
    case awarded = "AWARDED"
    case newAuthors = "NEW_AUTHORS"

    var title: String {
        switch self {
        case .toFinish: String(localized: "À finir")
        case .nextVolume: String(localized: "La suite")
        case .recommended: String(localized: "Recommandés")
        case .favoriteAuthors: String(localized: "Auteurs préférés")
        case .favoriteNarrators: String(localized: "Narrateurs préférés")
        case .awarded: String(localized: "Primés")
        case .newAuthors: String(localized: "Nouveaux auteurs")
        }
    }
}

/// A book a section offers, and the prize it won in "Primés".
struct PilePick: Identifiable, Hashable, Sendable, Codable {
    let book: Book
    var award: AwardMention?

    var id: String { book.id }
}

/// One section of the pile, never empty.
struct PileSection: Identifiable, Hashable, Sendable, Codable {
    let kind: PileSectionKind
    let picks: [PilePick]

    var id: String { kind.rawValue }
}

/// The pile as the server cut it: the format and genre pills and the sections.
struct Pile: Hashable, Sendable, Codable {
    /// The formats of the pile and of the books in progress, as the pills
    /// list them. One alone offers no pill.
    var formats: [BookFormat] = []
    /// The genres of the pile and of the books in progress in the format
    /// pill, in alphabetical order. One alone offers no pill.
    var genres: [BookGenre] = []
    var sections: [PileSection] = []
}

extension PileSection {
    /// What a cover says in this section: the reason it is there. A book in
    /// progress says it as the Library tab does — how far a recording got,
    /// since when a book is open, the bookmark hanging.
    func label(of pick: PilePick, now: Date = .now, calendar: Calendar = .current) -> PosterLabel {
        let book = pick.book
        switch kind {
        case .toFinish:
            if let progress = book.listeningProgress {
                return PosterLabel(caption: "\(progress)%", marksReading: true, progress: progress)
            }
            let since = book.startedAt ?? book.statusChangedAt ?? book.shelvedAt
            return PosterLabel(
                caption: since.map { PosterLabel.open($0, now: now, calendar: calendar) } ?? String(localized: "Commencé"),
                marksReading: true
            )
        case .nextVolume:
            return PosterLabel(caption: book.series?.label ?? book.title)
        case .recommended:
            guard let name = book.recommendation?.recommenderName else {
                return PosterLabel(caption: String(localized: "Recommandé"))
            }
            return PosterLabel(caption: String(localized: "Par \(Self.firstName(name))"))
        case .favoriteAuthors, .newAuthors:
            return PosterLabel(caption: book.authors.first.map(Self.surname) ?? "")
        case .favoriteNarrators:
            return PosterLabel(caption: book.narrators.first.map(Self.surname) ?? "")
        case .awarded:
            guard let award = pick.award else { return PosterLabel(caption: "") }
            return PosterLabel(caption: "\(award.award.stripName) \(String(award.year))")
        }
    }

    /// The particles a surname keeps in front of it: "Le Guin", "van Vogt".
    private static let particles: Set<String> = ["le", "la", "de", "du", "des", "d'", "van", "von", "der", "den", "di", "da", "del", "dos"]

    /// A name as a cover has room for: the surname, its particles kept —
    /// "Ursula K. Le Guin" is "Le Guin", "Frank Herbert" is "Herbert". A
    /// name in one word, or in a script without spaces, stays whole.
    static func surname(_ name: String) -> String {
        let words = name.split(separator: " ").map(String.init)
        guard words.count > 1 else { return name }
        var kept = [words[words.count - 1]]
        for word in words.dropLast().reversed() {
            guard particles.contains(word.lowercased()) else { break }
            kept.insert(word, at: 0)
        }
        return kept.joined(separator: " ")
    }

    /// The name a friend goes by: their first name, "Julie" for "Julie Martin".
    static func firstName(_ name: String) -> String {
        name.split(separator: " ").first.map(String.init) ?? name
    }
}
