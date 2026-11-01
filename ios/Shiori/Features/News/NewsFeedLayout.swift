import Foundation

/// One entry of the feed: a friend's move, the favourite author's
/// announcement, an award's winner, or a narrator's new book.
enum FeedItem: Identifiable, Hashable, Sendable {
    case friend(FeedEvent)
    case narrator(NarratorNews)
    case author(UpcomingRelease)
    case award(AwardWinner)

    var id: String {
        switch self {
        case let .friend(event): "friend-\(event.id)"
        case let .narrator(news): "narrator-\(news.id)"
        case let .author(release): "author-\(release.id)"
        case let .award(winner): "award-\(winner.id)"
        }
    }
}

/// A day's worth of the feed under its header.
struct FeedSection: Identifiable, Hashable, Sendable {
    let title: String
    let items: [FeedItem]
    var id: String { title }
}

enum NewsFeedLayout {
    /// The feed's one section, "Cette semaine", newest first: what is older
    /// than a week is not shown. A narrator's recording falls among the moves on
    /// the day it came out. The author's announcement slots in after the first
    /// two entries, the award's after the next two, so neither opens nor closes
    /// the page.
    static func sections(
        events: [FeedEvent],
        narrator: [NarratorNews] = [],
        spotlight: UpcomingRelease?,
        award: AwardWinner?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [FeedSection] {
        var dated: [(date: Date, item: FeedItem)] = events.map { ($0.at, .friend($0)) }
        if let first = narrator.first, let day = first.day(calendar: calendar) {
            let index = dated.firstIndex { $0.date < day } ?? dated.count
            dated.insert((day, .narrator(first)), at: index)
        }
        var items = dated.filter { isThisWeek($0.date, now: now, calendar: calendar) }.map(\.item)
        if let spotlight {
            items.insert(.author(spotlight), at: min(2, items.count))
        }
        if let award {
            items.insert(.award(award), at: min(4, items.count))
        }
        return [FeedSection(title: String(localized: "Cette semaine"), items: items)]
    }

    static func isThisWeek(_ date: Date, now: Date, calendar: Calendar) -> Bool {
        calendar.date(byAdding: .day, value: -7, to: now).map { date > $0 } ?? true
    }

    /// The formats the pills offer, in the board's order.
    static let pillFormats: [BookFormat] = [.book, .audiobook, .bandeDessinee, .comic, .manga]
}
