import Foundation

/// The reader's favourites as plain text, to send by mail or message or to
/// copy: one section per genre, its sagas then its books, one line each —
/// "Title — Author — Subgenre", the genre being the section's heading.
///
/// Plain text because it lands anywhere — a mail body, a chat, a note — and
/// somebody without Shiori reads it as easily as somebody with it. Any part
/// the record does not know is left out rather than written as a blank, and a
/// favourite with no genre goes under "Autres", last.
enum FavoritesSharing {
    static func text(sagas: [FriendSaga], books: [Book]) -> String {
        // A saga held in two languages is two rows on the shelf, but one work
        // to recommend.
        var seen = Set<String>()
        let sagaEntries = sagas.compactMap { saga -> Entry? in
            guard seen.insert("\(saga.name)\u{0}\(saga.author ?? "")").inserted else { return nil }
            return Entry(
                genre: saga.genre,
                line: line(title: saga.name, isSaga: true, author: saga.author, subgenre: saga.subgenre)
            )
        }
        let bookEntries = books.map {
            Entry(
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
        let genres = Set(entries.compactMap(\.genre))
            .sorted { $0.label.localizedCompare($1.label) == .orderedAscending }
        var sections = genres.map { genre in
            section(genre.label, entries.filter { $0.genre == genre })
        }
        let unclassified = entries.filter { $0.genre == nil }
        if !unclassified.isEmpty {
            sections.append(section(String(localized: "Autres"), unclassified))
        }
        return ([String(localized: "Mes favoris")] + sections).joined(separator: "\n\n")
    }

    private struct Entry {
        let genre: BookGenre?
        let line: String
    }

    private static func section(_ heading: String, _ entries: [Entry]) -> String {
        ([heading] + entries.map(\.line)).joined(separator: "\n")
    }

    private static func line(title: String, isSaga: Bool, author: String?, subgenre: String?) -> String {
        let name = isSaga ? String(localized: "\(title) (série)") : title
        return "• " + [name, author, subgenre].compactMap(\.self).joined(separator: " — ")
    }
}
