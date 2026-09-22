import Foundation

/// The reader's favourites as plain text, to send by mail or message or to
/// copy: one line per saga or book, "Title — Author — Genre / Subgenre".
///
/// Plain text because it lands anywhere — a mail body, a chat, a note — and
/// somebody without Shiori reads it as easily as somebody with it. Any part
/// the record does not know is left out rather than written as a blank.
enum FavoritesSharing {
    static func text(sagas: [FriendSaga], books: [Book]) -> String {
        var sections: [String] = [String(localized: "Mes favoris")]
        // A saga held in two languages is two rows on the shelf, but one work
        // to recommend.
        var seen = Set<String>()
        let sagaLines = sagas.compactMap { saga -> String? in
            guard seen.insert("\(saga.name)\u{0}\(saga.author ?? "")").inserted else { return nil }
            return line(title: saga.name, author: saga.author, genre: saga.genre, subgenre: saga.subgenre)
        }
        if !sagaLines.isEmpty {
            sections.append(([String(localized: "Séries")] + sagaLines).joined(separator: "\n"))
        }
        let bookLines = books.map {
            line(title: $0.title, author: $0.authors.isEmpty ? nil : $0.authorLine, genre: $0.genre, subgenre: $0.subgenres.first)
        }
        if !bookLines.isEmpty {
            sections.append(([String(localized: "Livres")] + bookLines).joined(separator: "\n"))
        }
        return sections.joined(separator: "\n\n")
    }

    private static func line(title: String, author: String?, genre: BookGenre?, subgenre: String?) -> String {
        let kind = [genre?.label, subgenre].compactMap(\.self).joined(separator: " / ")
        let parts = [title, author, kind.isEmpty ? nil : kind].compactMap(\.self)
        return "• " + parts.joined(separator: " — ")
    }
}
