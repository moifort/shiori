import Foundation

/// How "Toute la pile" is cut into sections: by how long the books have
/// waited, by format, or by genre.
enum PileGrouping: String, CaseIterable, Identifiable, Sendable {
    case date, format, genre

    var id: String { rawValue }

    var label: String {
        switch self {
        case .date: String(localized: "Par date")
        case .format: String(localized: "Par type")
        case .genre: String(localized: "Par genre")
        }
    }
}

/// The whole pile cut into its sections, and what each cover says there.
enum WholePile {
    /// How long a book has waited, as the sections by date name it: a span
    /// counted back from today, not a month of the calendar.
    enum Wait: Int, CaseIterable {
        case month, year, twoYears, older

        /// Up to how many days back the span reaches.
        var days: Int {
            switch self {
            case .month: 30
            case .year: 365
            case .twoYears: 730
            case .older: .max
            }
        }

        var title: String {
            switch self {
            case .month: String(localized: "Ce mois-ci")
            case .year: String(localized: "Moins d'un an")
            case .twoYears: String(localized: "1 à 2 ans")
            case .older: String(localized: "Plus de 2 ans")
            }
        }

        static func of(_ date: Date?, now: Date, calendar: Calendar) -> Wait {
            guard let date else { return .older }
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
            return allCases.first { days <= $0.days } ?? .older
        }
    }

    /// The pile cut by `grouping`, the books keeping the order they came in —
    /// the one added last first. By date the newest span comes first, by
    /// format the formats come in the app's order, by genre the fullest
    /// genre comes first.
    static func sections(
        _ books: [Book],
        by grouping: PileGrouping,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [ListSection<Book>] {
        switch grouping {
        case .date:
            let grouped = Dictionary(grouping: books) { Wait.of($0.shelvedAt, now: now, calendar: calendar) }
            return Wait.allCases.compactMap { wait in
                grouped[wait].map { ListSection(id: "wait-\(wait.rawValue)", title: wait.title, rows: $0) }
            }
        case .format:
            let grouped = Dictionary(grouping: books, by: \.format)
            return BookFormat.allCases.compactMap { format in
                grouped[format].map { ListSection(id: "format-\(format.rawValue)", title: format.shelfLabel, rows: $0) }
            }
        case .genre:
            let grouped = Dictionary(grouping: books) { $0.genre ?? .other }
            return grouped
                .sorted { ($0.value.count, $1.key.label) > ($1.value.count, $0.key.label) }
                .map { genre, rows in ListSection(id: "genre-\(genre.rawValue)", title: genre.label, rows: rows) }
        }
    }

    /// What a cover says: what its heading does not. By genre, how long the
    /// book has waited; otherwise its genre, shortened to fit, or how long it
    /// waited when it has none.
    static func label(
        of book: Book,
        by grouping: PileGrouping,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> PosterLabel {
        if grouping != .genre, let genre = book.genre {
            return PosterLabel(caption: genre.shortLabel)
        }
        return PosterLabel.of(book, in: .pile, now: now, calendar: calendar)
    }
}
