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

/// One of the page's headlines, "À la une": a release among what the reader
/// follows, out lately or announced for a day soon, or a friend's latest
/// favourite or finished book, and that day.
struct NewsHighlight: Identifiable, Hashable, Sendable {
    let day: Date
    let card: NewsCard

    var id: String { card.id }
}

/// The Découvrir page as an agenda: "À la une" first, the releases of what
/// the reader follows a few days back and ahead mixed with the friends' latest
/// moves; then only the days that bring something, a month back and a month
/// ahead — a quiet week leaves no empty leaf; then the shelves of each follow,
/// and the year's prizes. Pure: the same loads and the same day
/// always give the same agenda.
struct NewsAgenda: Hashable, Sendable {
    /// The days with news, oldest first: back to the oldest news loaded, on
    /// to the last day announced within `futureDays`.
    let days: [NewsAgendaDay]
    let today: Date
    /// The releases of what the reader follows nearest today, out lately then
    /// announced, oldest first.
    let highlights: [NewsHighlight]
    /// The winners crowned this year, the latest prize first; none hides the
    /// section.
    let prizes: [NewsCard]
    /// The rails under the agenda: friends' favourites, series, authors,
    /// narrators, wishes.
    let shelves: NewsShelves
    /// Whether the reader has any friend's move to show: without one, the
    /// page invites a friend.
    let hasFriends: Bool

    /// How many headlines the page shows on either side of today.
    static let highlightsEachSide = 4
    /// How many of the friends' latest moves join the headlines.
    static let friendHighlights = 2
    /// How far back the agenda reaches.
    static let pastDays = 30
    /// How far ahead the agenda reaches.
    static let futureDays = 31

    var isEmpty: Bool { days.isEmpty && highlights.isEmpty && prizes.isEmpty && shelves == .empty }

    /// The day the page opens on: today when it holds news, else the nearest
    /// day that does, the one to come on a tie.
    var openingDay: Date? {
        days.min { lhs, rhs in
            let left = abs(lhs.day.timeIntervalSince(today)), right = abs(rhs.day.timeIntervalSince(today))
            return left == right ? lhs.day > rhs.day : left < right
        }?.day
    }

    /// The headline the rail opens on: the nearest to come, else the last
    /// one out.
    var openingHighlight: String? {
        (highlights.first { $0.day > today } ?? highlights.last)?.id
    }

    init(
        days: [NewsAgendaDay],
        today: Date,
        highlights: [NewsHighlight],
        prizes: [NewsCard],
        shelves: NewsShelves = .empty,
        hasFriends: Bool
    ) {
        self.days = days
        self.today = today
        self.highlights = highlights
        self.prizes = prizes
        self.shelves = shelves
        self.hasFriends = hasFriends
    }

    /// An agenda with nothing in it.
    static func empty(now: Date = .now, calendar: Calendar = .current) -> NewsAgenda {
        NewsAgenda(released: [], events: [], upcoming: [], suggestions: [], awards: [], now: now, calendar: calendar)
    }

    /// - Parameters:
    ///   - upcoming: what is announced for a day, the strip's days to come.
    ///   - announced: everything announced, dated or not, for the shelves;
    ///     `upcoming` when nil.
    ///   - dismissed: cards turned down this session, gone at once.
    init(
        released: [ReleasedItem],
        events: [FeedEvent],
        upcoming: [UpcomingRelease],
        announced: [UpcomingRelease]? = nil,
        suggestions: [Suggestion],
        awards: [AwardSection],
        dismissed: Set<String> = [],
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        let today = calendar.startOfDay(for: now)
        let since = calendar.date(byAdding: .day, value: -Self.pastDays, to: today) ?? today
        let until = calendar.date(byAdding: .day, value: Self.futureDays, to: today) ?? today
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

        let past = byDay.filter { !$0.value.isEmpty }.map { NewsAgendaDay(day: $0.key, cards: $0.value) }
        let future = ahead.filter { $0.key <= until }.map { NewsAgendaDay(day: $0.key, cards: $0.value) }
        days = (past + future).sorted { $0.day < $1.day }
        self.today = today
        var out: [NewsHighlight] = []
        for item in released {
            let day = calendar.startOfDay(for: item.day)
            if day >= since, day <= today { out.append(NewsHighlight(day: day, card: .released(item))) }
        }
        out.sort { $0.day < $1.day }
        // The friends' latest favourites and finished books join what came out.
        let friends = moves
            .filter { $0.lead.kind != .started }
            .compactMap { move -> NewsHighlight? in
                let day = calendar.startOfDay(for: move.lead.at)
                return day >= since && day <= today ? NewsHighlight(day: day, card: .friend(move)) : nil
            }
            .sorted { $0.card.date ?? .distantPast > $1.card.date ?? .distantPast }
            .prefix(Self.friendHighlights)
        let before = (Array(out.suffix(Self.highlightsEachSide)) + friends).sorted { $0.day < $1.day }
        var coming: [NewsHighlight] = []
        for (day, cards) in ahead where day <= until {
            coming += cards.map { NewsHighlight(day: day, card: $0) }
        }
        coming.sort { $0.day == $1.day ? $0.id < $1.id : $0.day < $1.day }
        highlights = before + Array(coming.prefix(Self.highlightsEachSide))
        let year = calendar.component(.year, from: now)
        self.prizes = NewsDiscoverPicks.winners(awards)
            .filter { $0.mentions.first?.year == year }
            .map(NewsCard.award)
            .filter { !dismissed.contains($0.key) }
        shelves = NewsShelves(
            released: released, moves: moves, upcoming: announced ?? upcoming, today: today, calendar: calendar
        )
        hasFriends = !moves.isEmpty
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
