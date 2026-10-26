import Foundation

/// The line a poster carries inside its foot, and the marks beside it, as the
/// Library tab draws them: always in white. A paper book being read wears the
/// bookmark ribbon and says since when, never a page or a percentage the app
/// does not track; a recording adds a short bar and how far it got. A book read
/// shows its stars — five for a favourite, never a heart — or the day it was
/// finished. Units stick to their figure: "6j", "68%", "3sem.".
struct PosterLabel: Hashable, Sendable {
    var caption: String
    /// The white bookmark hanging from the top edge: the book is open.
    var marksReading = false
    /// How far a recording got, in percent, drawn as a short bar before the line.
    var progress: Int?
    /// How dark the cover is drawn: a book given up on is dimmed further.
    var dimming: Double = 0.12

    /// The dimming of a book given up on, or of a saga set aside.
    static let setAsideDimming = 0.5

    /// Where the poster is shown, which decides what its line says.
    enum Context: Sendable {
        /// What moved last, under rails and in "Récemment": "Ajouté",
        /// "Ajouté hier", "Il y a 3j", "depuis 6j", the stars.
        case recent
        /// "Récemment" cut into days: the day is the heading, so a book added
        /// is just "Ajouté", one started "Commencé".
        case journal
        /// The pile: how long the book has waited, "Aujourd'hui", "10 jours".
        case pile
        /// The books read: the stars, or "Lu le 3 oct.".
        case read
        /// The favourites on the entry screen: the year they were read.
        case lovedByYear
        /// The favourites on their own page, filed by year: the author.
        case lovedByAuthor
        /// The books given up on: how long ago, the cover dimmed.
        case dropped
    }

    /// The label of `book` in `context`, as of `now`.
    static func of(_ book: Book, in context: Context, now: Date = .now, calendar: Calendar = .current) -> PosterLabel {
        let since = book.shelvedAt ?? book.statusChangedAt
        switch context {
        case .pile:
            return PosterLabel(caption: since.map { waited($0, now: now, calendar: calendar) } ?? "")
        case .lovedByYear:
            if let date = since, book.status == .read {
                return PosterLabel(caption: String(localized: "Lu en \(String(calendar.component(.year, from: date)))"))
            }
            return PosterLabel(caption: book.authorLine)
        case .lovedByAuthor:
            return PosterLabel(caption: book.authors.joined(separator: " · "))
        case .dropped:
            let date = book.statusChangedAt ?? book.shelvedAt
            return PosterLabel(
                caption: date.map { waited($0, now: now, calendar: calendar) } ?? "",
                dimming: setAsideDimming
            )
        case .read:
            return readLabel(book, now: now, calendar: calendar)
        case .recent, .journal:
            return movedLabel(book, journal: context == .journal, since: since, now: now, calendar: calendar)
        }
    }

    private static func movedLabel(
        _ book: Book, journal: Bool, since: Date?, now: Date, calendar: Calendar
    ) -> PosterLabel {
        switch book.status {
        case .toRead:
            guard !journal, let since else { return PosterLabel(caption: String(localized: "Ajouté")) }
            return PosterLabel(caption: added(since, now: now, calendar: calendar))
        case .reading:
            if let progress = book.listeningProgress {
                return PosterLabel(caption: "\(progress)%", marksReading: true, progress: progress)
            }
            guard !journal, let since else { return PosterLabel(caption: String(localized: "Commencé"), marksReading: true) }
            return PosterLabel(caption: open(since, now: now, calendar: calendar), marksReading: true)
        case .read:
            return readLabel(book, now: now, calendar: calendar)
        case .dropped:
            return PosterLabel(caption: String(localized: "Abandonné"), dimming: setAsideDimming)
        }
    }

    private static func readLabel(_ book: Book, now: Date, calendar: Calendar) -> PosterLabel {
        if book.favorite { return PosterLabel(caption: stars(5)) }
        if let rating = book.shownRating { return PosterLabel(caption: stars(rating)) }
        guard let date = book.shelvedAt else { return PosterLabel(caption: String(localized: "Lu")) }
        if calendar.isDate(date, inSameDayAs: now) { return PosterLabel(caption: String(localized: "Lu aujourd'hui")) }
        if calendar.isDateInYesterday(date, relativeTo: now) { return PosterLabel(caption: String(localized: "Lu hier")) }
        return PosterLabel(caption: String(localized: "Lu le \(date.formatted(.dateTime.day().month(.abbreviated)))"))
    }

    /// Whole stars, and a half where the rating has one: "★★★★", "★★★½".
    static func stars(_ rating: Double) -> String {
        let whole = Int(rating.rounded(.down))
        let half = rating - Double(whole) >= 0.5
        return String(repeating: "★", count: max(0, min(whole, 5))) + (half ? "½" : "")
    }

    // MARK: - Spans

    /// How long a book has waited: "Aujourd'hui", "Hier", "10 jours", "3sem.",
    /// "2 mois", "1 an".
    static func waited(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        switch Span(from: date, to: now, calendar: calendar) {
        case .today: String(localized: "Aujourd'hui")
        case .yesterday: String(localized: "Hier")
        case let .days(days): String(localized: "\(days) jours")
        case let .weeks(weeks): String(localized: "\(weeks)sem.")
        case let .months(months): String(localized: "\(months) mois")
        case let .years(years): years == 1 ? String(localized: "1 an") : String(localized: "\(years) ans")
        }
    }

    /// When a book was added: "Ajouté", "Ajouté hier", "Il y a 3j",
    /// "Il y a 2sem.", "Il y a 4 mois", "Il y a 1 an".
    static func added(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        switch Span(from: date, to: now, calendar: calendar) {
        case .today: String(localized: "Ajouté")
        case .yesterday: String(localized: "Ajouté hier")
        case let .days(days): String(localized: "Il y a \(days)j")
        case let .weeks(weeks): String(localized: "Il y a \(weeks)sem.")
        case let .months(months): String(localized: "Il y a \(months) mois")
        case let .years(years): years == 1 ? String(localized: "Il y a 1 an") : String(localized: "Il y a \(years) ans")
        }
    }

    /// Since when a book is open: "Commencé", "depuis hier", "depuis 6j",
    /// "depuis 3sem.", "depuis 2 mois", "depuis 1 an".
    static func open(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        switch Span(from: date, to: now, calendar: calendar) {
        case .today: String(localized: "Commencé")
        case .yesterday: String(localized: "depuis hier")
        case let .days(days): String(localized: "depuis \(days)j")
        case let .weeks(weeks): String(localized: "depuis \(weeks)sem.")
        case let .months(months): String(localized: "depuis \(months) mois")
        case let .years(years): years == 1 ? String(localized: "depuis 1 an") : String(localized: "depuis \(years) ans")
        }
    }

    /// A span between two days as a cover says it: in days under two weeks, in
    /// weeks under a month, in months under a year.
    enum Span: Equatable {
        case today, yesterday
        case days(Int), weeks(Int), months(Int), years(Int)

        init(from date: Date, to now: Date, calendar: Calendar = .current) {
            let start = calendar.startOfDay(for: date)
            let end = calendar.startOfDay(for: now)
            let days = max(0, calendar.dateComponents([.day], from: start, to: end).day ?? 0)
            let span = calendar.dateComponents([.month, .year], from: start, to: end)
            if days == 0 { self = .today }
            else if days == 1 { self = .yesterday }
            else if days < 14 { self = .days(days) }
            else if (span.month ?? 0) < 1, (span.year ?? 0) < 1 { self = .weeks(days / 7) }
            else if let years = span.year, years > 0 { self = .years(years) }
            else { self = .months(max(1, span.month ?? 1)) }
        }
    }
}

private extension Calendar {
    func isDateInYesterday(_ date: Date, relativeTo now: Date) -> Bool {
        guard let yesterday = self.date(byAdding: .day, value: -1, to: now) else { return false }
        return isDate(date, inSameDayAs: yesterday)
    }
}
