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
    /// The feed grouped by how long ago, newest first: "Aujourd'hui", "Hier",
    /// "Cette semaine", "Plus tôt". The author's announcement slots in after
    /// the first two moves, the award's after the next two, so neither opens
    /// nor closes the page.
    static func sections(
        events: [FeedEvent],
        narrator: [NarratorNews] = [],
        spotlight: UpcomingRelease?,
        award: AwardWinner?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [FeedSection] {
        var buckets: [(title: String, items: [FeedItem])] = []
        for event in events {
            let title = bucketTitle(of: event.at, now: now, calendar: calendar)
            if buckets.last?.title == title {
                buckets[buckets.count - 1].items.append(.friend(event))
            } else {
                buckets.append((title, [.friend(event)]))
            }
        }
        if buckets.isEmpty { buckets = [(String(localized: "Cette semaine"), [])] }
        if let spotlight {
            buckets[0].items.insert(.author(spotlight), at: min(2, buckets[0].items.count))
        }
        if let first = narrator.first {
            buckets[0].items.insert(.narrator(first), at: min(1, buckets[0].items.count))
        }
        if let award {
            let target = buckets.count > 1 ? 1 : 0
            buckets[target].items.insert(.award(award), at: min(target == 0 ? 4 : 0, buckets[target].items.count))
        }
        return buckets.map { FeedSection(title: $0.title, items: $0.items) }
    }

    static func bucketTitle(of date: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return String(localized: "Aujourd'hui") }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
            calendar.isDate(date, inSameDayAs: yesterday)
        {
            return String(localized: "Hier")
        }
        if let week = calendar.date(byAdding: .day, value: -7, to: now), date > week {
            return String(localized: "Cette semaine")
        }
        return String(localized: "Plus tôt")
    }

    /// The formats the pills offer, in the board's order.
    static let pillFormats: [BookFormat] = [.book, .audiobook, .bandeDessinee, .comic, .manga]
}
