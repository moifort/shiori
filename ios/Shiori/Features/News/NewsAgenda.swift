import Foundation

/// One book of the Découvrir agenda, whatever brought it: a friend's move, a
/// release among what the reader follows, the month's discovery or a prize.
/// The cover carries the book; the card only says why it is there.
enum NewsCard: Identifiable, Hashable, Sendable {
    case friend(FriendMove)
    case released(ReleasedItem)
    case upcoming(UpcomingRelease)
    case suggestion(Suggestion)
    case award(AwardWinner)

    var id: String {
        switch self {
        case let .friend(move): "friend-\(move.id)"
        case let .released(item): item.id
        case let .upcoming(release): "upcoming-\(release.id)"
        case let .suggestion(suggestion): "suggestion-\(suggestion.id)"
        case let .award(winner): "award-\(winner.id)"
        }
    }

    /// What `taken`, `wished` and `dismissed` remember it by: a friend's book
    /// by its book id, as the rest of the tab does.
    var key: String {
        switch self {
        case let .friend(move): move.lead.bookId
        default: id
        }
    }

    var cover: Book {
        switch self {
        case let .friend(move): move.lead.cover
        case let .released(item): item.cover
        case let .upcoming(release): release.cover
        case let .suggestion(suggestion): suggestion.cover
        case let .award(winner): winner.cover
        }
    }

    /// When it happened, for the day the agenda files it under; nil for what
    /// has no day of its own.
    var date: Date? {
        switch self {
        case let .friend(move): move.lead.at
        case let .released(item): item.day
        default: nil
        }
    }

    /// A "Pas intéressé" the server keeps: the month's discovery and a prize.
    var isDismissable: Bool {
        switch self {
        case .suggestion, .award: true
        default: false
        }
    }
}

/// One day of the agenda and what it brought: the friends' moves and the
/// releases dated to it, and on today what has no day of its own — the
/// prizes, then the month's discoveries.
struct NewsAgendaDay: Identifiable, Hashable, Sendable {
    let day: Date
    let cards: [NewsCard]

    var id: Date { day }
}

/// The Découvrir page as an agenda: the week in seven days, what each one
/// brought or will bring, and the days to come with a release on them. Pure:
/// the same loads and the same day always give the same agenda.
struct NewsAgenda: Hashable, Sendable {
    /// The weeks a reader can page through, oldest first, Monday to Sunday:
    /// back to the oldest news loaded, on to the last day announced.
    let weeks: [[NewsAgendaDay]]
    /// Where the current week sits in `weeks`.
    let currentWeek: Int
    let today: Date
    /// After today, the days with a release announced for them, soonest first.
    let coming: [NewsAgendaDay]
    /// Whether the reader has any friend's move to show: without one, the
    /// page invites a friend.
    let hasFriends: Bool

    /// How many days to come the page lists under the agenda.
    static let comingCount = 4
    /// How far back the agenda reaches.
    static let pastDays = 30
    /// How far ahead the weeks run.
    static let futureWeeks = 4

    var isEmpty: Bool {
        weeks.allSatisfy { $0.allSatisfy(\.cards.isEmpty) } && coming.isEmpty
    }

    init(weeks: [[NewsAgendaDay]], currentWeek: Int, today: Date, coming: [NewsAgendaDay], hasFriends: Bool) {
        self.weeks = weeks
        self.currentWeek = currentWeek
        self.today = today
        self.coming = coming
        self.hasFriends = hasFriends
    }

    /// An agenda with nothing in it.
    static func empty(now: Date = .now, calendar: Calendar = .current) -> NewsAgenda {
        NewsAgenda(released: [], events: [], upcoming: [], suggestions: [], awards: [], now: now, calendar: calendar)
    }

    /// - Parameter dismissed: cards turned down this session, gone at once.
    init(
        released: [ReleasedItem],
        events: [FeedEvent],
        upcoming: [UpcomingRelease],
        suggestions: [Suggestion],
        awards: [AwardSection],
        dismissed: Set<String> = [],
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        var calendar = calendar
        // The week opens on Monday, as a French agenda does.
        calendar.firstWeekday = 2
        let today = calendar.startOfDay(for: now)
        let since = calendar.date(byAdding: .day, value: -Self.pastDays, to: today) ?? today
        let moves = NewsFeedLayout.friendSections(events: events, now: now, calendar: calendar)
            .flatMap(\.moves)
        var byDay: [Date: [NewsCard]] = [:]
        // A day's news newest first: the friends' moves and the releases.
        let dated = (moves.map(NewsCard.friend) + released.map(NewsCard.released))
            .compactMap { card -> (Date, NewsCard)? in
                guard let date = card.date else { return nil }
                let day = calendar.startOfDay(for: date)
                return day >= since && day <= today ? (day, card) : nil
            }
            .sorted { ($0.1.date ?? .distantPast) > ($1.1.date ?? .distantPast) }
        for (day, card) in dated { byDay[day, default: []].append(card) }
        // What is announced for an exact day after today.
        var ahead: [Date: [NewsCard]] = [:]
        for release in upcoming {
            guard let day = Self.exactDay(release.date, calendar: calendar), day > today else { continue }
            ahead[day, default: []].append(.upcoming(release))
        }
        // Today opens on the prizes, then the month's discoveries, before its
        // own news: they have no day, and today is when they are read.
        let prizes = NewsDiscoverPicks.winners(awards).map(NewsCard.award).filter { !dismissed.contains($0.key) }
        let picks = suggestions.map(NewsCard.suggestion).filter { !dismissed.contains($0.key) }
        byDay[today] = Array(prizes.prefix(2)) + (byDay[today] ?? []) + Array(picks.prefix(1))

        let monday = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let oldest = byDay.filter { !$0.value.isEmpty }.keys.min() ?? today
        let latest = ahead.keys.filter {
            $0 < (calendar.date(byAdding: .weekOfYear, value: Self.futureWeeks, to: monday) ?? today)
        }.max() ?? today
        let firstMonday = calendar.dateInterval(of: .weekOfYear, for: oldest)?.start ?? monday
        let lastMonday = calendar.dateInterval(of: .weekOfYear, for: latest)?.start ?? monday
        var weeks: [[NewsAgendaDay]] = []
        var start = firstMonday
        while start <= lastMonday {
            weeks.append((0..<7).compactMap { offset in
                guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
                return NewsAgendaDay(day: day, cards: day > today ? ahead[day] ?? [] : byDay[day] ?? [])
            })
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: start) else { break }
            start = next
        }
        self.weeks = weeks
        currentWeek = weeks.firstIndex { $0.first?.day == monday } ?? 0
        self.today = today
        coming = ahead.keys.sorted().prefix(Self.comingCount).map { NewsAgendaDay(day: $0, cards: ahead[$0] ?? []) }
        hasFriends = !moves.isEmpty
    }

    /// A day's place in the weeks, today's by default.
    func position(of day: Date) -> (week: Int, day: Int)? {
        for (week, days) in weeks.enumerated() {
            if let index = days.firstIndex(where: { $0.day == day }) { return (week, index) }
        }
        return nil
    }

    /// The day of a `YYYY-MM-DD` date; nil for a month or a year alone.
    static func exactDay(_ date: String?, calendar: Calendar) -> Date? {
        guard let parts = date?.split(separator: "-").compactMap({ Int($0) }), parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

/// The prizes in the order the page shows them.
enum NewsDiscoverPicks {
    /// The winners of every list, the latest prize first, each novel once.
    static func winners(_ sections: [AwardSection]) -> [AwardWinner] {
        var seen = Set<String>()
        return sections.flatMap(\.winners)
            .sorted { ($0.mentions.first?.year ?? 0) > ($1.mentions.first?.year ?? 0) }
            .filter { seen.insert($0.id).inserted }
    }
}
