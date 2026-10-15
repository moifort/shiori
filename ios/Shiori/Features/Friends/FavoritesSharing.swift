import SwiftUI

/// The reader's favourites as plain text, to send by mail or message or to
/// copy: one part per format — novels, BD and manga are shelved apart, and a
/// reader asking for a BD does not want it lost among novels — then one
/// section per genre within it, its sagas then its books, one line each —
/// "Title — Author — Subgenre", the genre being the section's heading.
///
/// Plain text because it lands anywhere — a mail body, a chat, a note — and
/// somebody without Shiori reads it as easily as somebody with it. Any part
/// the record does not know is left out rather than written as a blank, and a
/// favourite with no genre goes under "Autres", last.
enum FavoritesSharing {
    /// A shelf's favourites as text; nil when nothing is hearted and there is
    /// nothing to send.
    static func text(of shelf: FriendProfile) -> String? {
        guard !(shelf.favoriteSagas.isEmpty && shelf.favorites.isEmpty) else { return nil }
        return text(sagas: shelf.favoriteSagas, books: shelf.favorites.map(\.book))
    }

    static func text(sagas: [FriendSaga], books: [Book]) -> String {
        // A saga held in two languages is two rows on the shelf, but one work
        // to recommend.
        var seen = Set<String>()
        let sagaEntries = sagas.compactMap { saga -> Entry? in
            let format = format(of: saga)
            guard seen.insert("\(saga.name)\u{0}\(saga.author ?? "")\u{0}\(format)").inserted else {
                return nil
            }
            return Entry(
                format: format,
                genre: saga.genre,
                line: line(title: saga.name, isSaga: true, author: saga.author, subgenre: saga.subgenre)
            )
        }
        let bookEntries = books.map {
            Entry(
                format: $0.format,
                genre: $0.genre,
                line: line(
                    title: $0.title,
                    isSaga: false,
                    author: $0.authors.isEmpty ? nil : $0.authorLine,
                    subgenre: $0.subgenres.first
                )
            )
        }
        let entries = sagaEntries + bookEntries
        let parts = BookFormat.allCases.compactMap { format -> String? in
            let held = entries.filter { $0.format == format }
            guard !held.isEmpty else { return nil }
            return ([heading(of: format).localizedUppercase] + genreSections(held))
                .joined(separator: "\n\n")
        }
        return ([String(localized: "Mes favoris")] + parts).joined(separator: "\n\n")
    }

    private struct Entry {
        let format: BookFormat
        let genre: BookGenre?
        let line: String
    }

    private static func genreSections(_ entries: [Entry]) -> [String] {
        let genres = Set(entries.compactMap(\.genre))
            .sorted { $0.label.localizedCompare($1.label) == .orderedAscending }
        var sections = genres.map { genre in
            section(genre.label, entries.filter { $0.genre == genre })
        }
        let unclassified = entries.filter { $0.genre == nil }
        if !unclassified.isEmpty {
            sections.append(section(String(localized: "Autres"), unclassified))
        }
        return sections
    }

    /// A saga is what most of its volumes are; one whose volumes did not come
    /// along is a novel, or a recording when it is heard.
    private static func format(of saga: FriendSaga) -> BookFormat {
        let formats = saga.volumes.map(\.format)
        // A tie goes to the format listed first, so the text does not change
        // from one send to the next.
        return BookFormat.allCases
            .filter(formats.contains)
            .max { left, right in
                formats.count { $0 == left } < formats.count { $0 == right }
            } ?? (saga.isAudio ? .audiobook : .book)
    }

    /// The format as a part's heading: what the reader shelves, in the plural.
    private static func heading(of format: BookFormat) -> String {
        switch format {
        case .book: String(localized: "Livres")
        case .audiobook: String(localized: "Livres audio")
        case .bandeDessinee: String(localized: "BD")
        case .comic: String(localized: "Comics")
        case .manga: String(localized: "Mangas")
        }
    }

    private static func section(_ heading: String, _ entries: [Entry]) -> String {
        ([heading] + entries.map(\.line)).joined(separator: "\n")
    }

    private static func line(title: String, isSaga: Bool, author: String?, subgenre: String?) -> String {
        let name = isSaga ? String(localized: "\(title) (série)") : title
        return "• " + [name, author, subgenre].compactMap(\.self).joined(separator: " — ")
    }
}
