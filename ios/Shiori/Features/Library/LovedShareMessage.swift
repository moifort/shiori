import Foundation

/// "Coups de cœur" as a message for WhatsApp or any chat: cut by genre, then
/// by format, a saga on one line whatever number of its volumes are loved, a
/// book outside any saga on its own line. A recording counts as the book it
/// reads, as paper and screen already do. Bold and italics are WhatsApp's
/// asterisks and underscores, which other apps show as they are.
enum LovedShareMessage {
    static func text(books: [Book], series: [FollowedSeries]) -> String {
        var entries: [Entry] = []
        var seen = Set<String>()
        func add(_ entry: Entry) {
            guard seen.insert(entry.key).inserted else { return }
            entries.append(entry)
        }
        for saga in series {
            add(Entry(genre: saga.genre, format: saga.volumes.first?.format ?? .book, name: saga.name, author: saga.author, isSeries: true))
        }
        for book in books {
            if let membership = book.series, !membership.name.isEmpty {
                add(Entry(genre: book.genre, format: book.format, name: membership.name, author: book.authors.first, isSeries: true))
            } else {
                add(Entry(genre: book.genre, format: book.format, name: book.title, author: book.authorList, isSeries: false))
            }
        }

        var lines = [String(localized: "Mes coups de cœur 📚")]
        let byGenre = Dictionary(grouping: entries) { $0.genre ?? .other }
        for genre in BookGenre.alphabetical {
            guard let ofGenre = byGenre[genre] else { continue }
            lines += ["", "*\(genre.label)*"]
            let byFormat = Dictionary(grouping: ofGenre, by: \.format)
            let formats = BookFormat.allCases.filter { byFormat[$0] != nil }
            for format in formats {
                if formats.count > 1 || format != .book {
                    lines.append("_\(format.label)_")
                }
                lines += byFormat[format, default: []].sorted(by: Entry.order).map(\.line)
            }
        }
        return lines.joined(separator: "\n")
    }

    private struct Entry {
        let genre: BookGenre?
        let format: BookFormat
        let name: String
        let author: String?
        let isSeries: Bool

        init(genre: BookGenre?, format: BookFormat, name: String, author: String?, isSeries: Bool) {
            self.genre = genre
            self.format = format == .audiobook ? .book : format
            self.name = name
            self.author = author
            self.isSeries = isSeries
        }

        /// One saga per format: its loved volumes and its heart are one line.
        var key: String {
            "\(isSeries ? "series" : "book")|\(format.rawValue)|\(name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil))"
        }

        var line: String {
            let title = isSeries ? String(localized: "\(name) (série)") : name
            guard let author, !author.isEmpty else { return "• \(title)" }
            return "• \(title) — \(author)"
        }

        /// The sagas first, then the books on their own, each by name.
        static func order(_ lhs: Entry, _ rhs: Entry) -> Bool {
            if lhs.isSeries != rhs.isSeries { return lhs.isSeries }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
}

private extension Book {
    var authorList: String? {
        authors.isEmpty ? nil : authors.joined(separator: ", ")
    }
}
