import Foundation

/// One book of the Découvrir page, whatever brought it: a friend's move, a
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

    /// When it happened, for the order of "Aujourd'hui"; nil for what has no
    /// day of its own.
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

/// The Découvrir page, laid out from what the tab loaded: the latest news as
/// stories, then the friends, the releases and discoveries, the prizes.
struct NewsDiscoverLayout: Hashable, Sendable {
    let today: [NewsCard]
    let friends: [NewsCard]
    let releases: [NewsCard]
    let awards: [NewsCard]

    var isEmpty: Bool { today.isEmpty && friends.isEmpty && releases.isEmpty && awards.isEmpty }

    /// How many stories "Aujourd'hui" holds at most.
    static let storyCount = 6
    /// How far back a story reaches.
    static let storyDays = 7
    /// How many covers a wall shows.
    static let wallCount = 6

    init(today: [NewsCard], friends: [NewsCard], releases: [NewsCard], awards: [NewsCard]) {
        self.today = today
        self.friends = friends
        self.releases = releases
        self.awards = awards
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
        let since = calendar.date(byAdding: .day, value: -Self.storyDays, to: calendar.startOfDay(for: now)) ?? now
        let moves = NewsFeedLayout.friendSections(events: events, now: now, calendar: calendar)
            .flatMap(\.moves)
            .map(NewsCard.friend)
        let out = released.map(NewsCard.released)
        let prizes = Self.winners(awards).map(NewsCard.award).filter { !dismissed.contains($0.key) }
        let picks = suggestions.map(NewsCard.suggestion).filter { !dismissed.contains($0.key) }

        // The latest of what happened, newest first; a quiet week leads with a
        // prize and the month's discovery rather than nothing.
        var today = (moves + out)
            .filter { ($0.date ?? .distantPast) >= since }
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        if today.count < 2 {
            today += [prizes.first, picks.first].compactMap { $0 }
        }
        // The walls keep what the stories tell: a story is gone once seen,
        // the friends' books and the releases stay to come back to.
        self.today = Array(today.prefix(Self.storyCount))
        friends = Self.wall(moves)
        releases = Self.wall(Self.interleave(out + upcoming.map(NewsCard.upcoming), picks))
        self.awards = Array(prizes.prefix(Self.wallCount))
    }

    /// The winners of every list, the latest prize first, each novel once.
    static func winners(_ sections: [AwardSection]) -> [AwardWinner] {
        var seen = Set<String>()
        return sections.flatMap(\.winners)
            .sorted { ($0.mentions.first?.year ?? 0) > ($1.mentions.first?.year ?? 0) }
            .filter { seen.insert($0.id).inserted }
    }

    /// A wall's covers, two by two: an odd one out would leave a hole beside
    /// it, unless it is the only one.
    private static func wall(_ cards: [NewsCard]) -> [NewsCard] {
        let shown = Array(cards.prefix(wallCount))
        return shown.count > 1 && shown.count.isMultiple(of: 2) == false ? Array(shown.dropLast()) : shown
    }

    /// One of each in turn, so the wall mixes releases and discoveries.
    private static func interleave(_ first: [NewsCard], _ second: [NewsCard]) -> [NewsCard] {
        var mixed: [NewsCard] = []
        for index in 0..<max(first.count, second.count) {
            if index < first.count { mixed.append(first[index]) }
            if index < second.count { mixed.append(second[index]) }
        }
        return mixed
    }
}
