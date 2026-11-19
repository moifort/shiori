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
    /// The awaited edition an announced card of the wish list's rail stands
    /// for: its id is the server's `awaited~<editionId>`.
    var awaitedEditionId: String? {
        guard case let .upcoming(release) = self, release.source == .awaited else { return nil }
        let parts = release.id.split(separator: "~", maxSplits: 1)
        return parts.count == 2 && parts[0] == "awaited" ? String(parts[1]) : nil
    }

    /// Whether the server says the reader holds the book already, in any
    /// format: a friend's book, a prize's winner. The other cards are of
    /// books the server leaves out once held.
    var inLibrary: Bool {
        switch self {
        case let .friend(move): move.lead.inLibrary
        case let .award(winner): winner.inLibrary ?? false
        default: false
        }
    }

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

/// The Découvrir page as an agenda: "À la une" first, the releases of what
/// the reader follows a few days back and ahead mixed with the friends' latest
/// moves; then only the days that bring something, a month back and every
/// announced day ahead — a quiet week leaves no empty leaf; then the shelves of each follow,
/// and the year's prizes. Pure: the same loads and the same day
/// always give the same agenda.
struct NewsAgenda: Hashable, Sendable {
    /// The days with news, oldest first: back to the oldest news loaded, on
    /// to the last day announced, however far ahead.
    let days: [NewsAgendaDay]
    let today: Date
    /// "À la une": the friends' coups de cœur and the releases of what the
    /// reader follows out in the last `headlinePastDays`, newest first, then
    /// what is announced for a day within `headlineFutureDays`, soonest
    /// first. No prize: they have their own section.
    let headlines: [NewsShelfItem]
    /// The winners crowned this year, the latest prize first; none hides the
    /// section.
    let prizes: [NewsCard]
    /// The rails under the agenda: friends' favourites, series, authors,
    /// narrators, wishes.
    let shelves: NewsShelves
    /// Whether the reader has any friend's move to show: without one, the
    /// page invites a friend.
    let hasFriends: Bool

    /// How far back the headlines reach.
    static let headlinePastDays = 20
    /// How far ahead the headlines reach.
    static let headlineFutureDays = 30
    /// How far back the agenda reaches. Ahead it has no end: every day a
    /// release is announced for is in the strip.
    static let pastDays = 30

    var isEmpty: Bool { days.isEmpty && headlines.isEmpty && prizes.isEmpty && shelves == .empty }

    /// The day the page opens on: today when it holds news, else the nearest
    /// day that does, the one to come on a tie.
    var openingDay: Date? {
        days.min { lhs, rhs in
            let left = abs(lhs.day.timeIntervalSince(today)), right = abs(rhs.day.timeIntervalSince(today))
            return left == right ? lhs.day > rhs.day : left < right
        }?.day
    }

    init(
        days: [NewsAgendaDay],
        today: Date,
        headlines: [NewsShelfItem],
        prizes: [NewsCard],
        shelves: NewsShelves = .empty,
        hasFriends: Bool
    ) {
        self.days = days
        self.today = today
        self.headlines = headlines
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
    ///   - wishlist: the wish list rail, in the server's order.
    ///   - dismissed: cards turned down this session, gone at once.
    init(
        released: [ReleasedItem],
        events: [FeedEvent],
        upcoming: [UpcomingRelease],
        announced: [UpcomingRelease]? = nil,
        wishlist: [UpcomingRelease] = [],
        suggestions: [Suggestion],
        awards: [AwardSection],
        dismissed: Set<String> = [],
        now: Date = .now,
        calendar: Calendar = .current
    ) {
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
        // The month's discovery closes today: it has no day, and today is
        // when it is read. The prizes stay in their own section.
        let picks = suggestions.map(NewsCard.suggestion).filter { !dismissed.contains($0.key) }
        byDay[today] = (byDay[today] ?? []) + Array(picks.prefix(1))

        let past = byDay.filter { !$0.value.isEmpty }.map { NewsAgendaDay(day: $0.key, cards: $0.value) }
        let future = ahead.map { NewsAgendaDay(day: $0.key, cards: $0.value) }
        days = (past + future).sorted { $0.day < $1.day }
        self.today = today
        headlines = Self.headlines(
            released: released, moves: moves, upcoming: upcoming, today: today, calendar: calendar
        )
        let year = calendar.component(.year, from: now)
        self.prizes = NewsDiscoverPicks.winners(awards)
            .filter { $0.mentions.first?.year == year }
            .map(NewsCard.award)
            .filter { !dismissed.contains($0.key) }
        shelves = NewsShelves(
            released: released, moves: moves, upcoming: announced ?? upcoming, wishlist: wishlist,
            today: today, calendar: calendar
        )
        hasFriends = !moves.isEmpty
    }

    /// The friends' coups de cœur and the releases out lately, newest first,
    /// then the releases announced for a day soon, soonest first.
    static func headlines(
        released: [ReleasedItem], moves: [FriendMove], upcoming: [UpcomingRelease], today: Date, calendar: Calendar
    ) -> [NewsShelfItem] {
        let since = calendar.date(byAdding: .day, value: -headlinePastDays, to: today) ?? today
        let until = calendar.date(byAdding: .day, value: headlineFutureDays, to: today) ?? today
        let past = (moves.filter { $0.lead.kind == .loved }.map(NewsCard.friend) + released.map(NewsCard.released))
            .compactMap { card -> (Date, NewsCard)? in
                guard let date = card.date, calendar.startOfDay(for: date) >= since else { return nil }
                return (date, card)
            }
            .sorted { $0.0 > $1.0 }
            .map(\.1)
        let ahead = upcoming
            .compactMap { release -> (Date, NewsCard)? in
                guard let day = exactDay(release.date, calendar: calendar), day > today, day <= until else { return nil }
                return (day, .upcoming(release))
            }
            .sorted { $0.0 == $1.0 ? $0.1.id < $1.1.id : $0.0 < $1.0 }
            .map(\.1)
        var seen = Set<String>()
        return (past + ahead)
            .filter { seen.insert($0.key).inserted }
            .map { NewsShelves.item($0, calendar: calendar) }
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

/// What the reader made of the cards' buttons on this visit: the books
/// just wished for, by `NewsCard.key`, the awaited editions of the wish
/// list's rail just taken off it, which their card no longer shows wished,
/// and the books just taken with the "+".
struct NewsWishes: Equatable, ExpressibleByArrayLiteral {
    private var added: Set<String> = []
    private var dropped: Set<String> = []
    private var taken: Set<String> = []

    init(arrayLiteral keys: String...) { added = Set(keys) }

    func contains(_ key: String) -> Bool { added.contains(key) }

    /// A large card's state: wished here, or awaited already and not taken off.
    func isWished(_ item: NewsShelfItem) -> Bool {
        let key = item.card.key
        return added.contains(key) || (item.isAwaited && !dropped.contains(key))
    }

    /// A large card's book held already, as the server says, or just taken
    /// here: "Chez vous" in place of its buttons.
    func isOwned(_ card: NewsCard) -> Bool {
        card.inLibrary || taken.contains(card.key)
    }

    mutating func take(_ key: String) { taken.insert(key) }

    mutating func insert(_ key: String) {
        added.insert(key)
        dropped.remove(key)
    }

    mutating func remove(_ key: String) { added.remove(key) }
    mutating func drop(_ key: String) { dropped.insert(key) }
    mutating func restore(_ key: String) { dropped.remove(key) }
}
