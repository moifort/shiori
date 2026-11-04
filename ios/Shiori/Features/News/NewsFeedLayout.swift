import Foundation

/// The two halves of the tab: what came out and is coming from what the reader
/// follows, and what their friends did.
enum NewsTab: String, CaseIterable, Identifiable, Sendable {
    case releases, friends

    var id: String { rawValue }

    var label: String {
        switch self {
        case .releases: String(localized: "Sorties")
        case .friends: String(localized: "Amis")
        }
    }
}

/// One line of "Sorti": a series' volume or an awaited edition now out, or a
/// recording a narrator the reader follows lent their voice to.
enum ReleasedItem: Identifiable, Hashable, Sendable {
    case release(UpcomingRelease, day: Date)
    case narrator(NarratorNews, day: Date)

    var id: String {
        switch self {
        case let .release(release, _): "release-\(release.id)"
        case let .narrator(news, _): "narrator-\(news.id)"
        }
    }

    var day: Date {
        switch self {
        case let .release(_, day), let .narrator(_, day): day
        }
    }

    var cover: Book {
        switch self {
        case let .release(release, _): release.cover
        case let .narrator(news, _): news.cover
        }
    }

    var title: String {
        switch self {
        case let .release(release, _): release.title ?? release.cover.title
        case let .narrator(news, _): news.title
        }
    }

    var authors: [String] {
        switch self {
        case let .release(release, _): release.authors
        case let .narrator(news, _): news.authors
        }
    }

    var format: BookFormat {
        switch self {
        case let .release(release, _): release.format
        case .narrator: .audiobook
        }
    }

    /// Why the reader is told of it, under its author; nil when the signature
    /// says it all.
    var subtitle: String? {
        guard case let .release(release, _) = self else { return nil }
        switch release.source {
        case .saga, .awaited:
            let reason = release.format == .audiobook && release.source == .awaited
                ? String(localized: "Dans votre liste d'envie")
                : release.reason
            return reason.isEmpty ? nil : reason
        case .author, .narrator:
            return nil
        }
    }

    /// The book as an addition, a wish or an await would send it.
    var draft: BookDraft {
        var draft = BookDraft(title: title, authors: authors)
        draft.format = format
        draft.media = format == .audiobook ? [] : [.print]
        draft.coverURL = cover.coverURL
        return draft
    }
}

/// The lines of "Sorti" under one journal period.
struct ReleasedSection: Identifiable, Hashable, Sendable {
    let title: String
    let items: [ReleasedItem]
    var id: String { title }
}

/// A friend's move, with the other friends who made the same one on the same
/// story in the same period: "Sophie, Marc et 1 autre ont commencé Vagabond".
struct FriendMove: Identifiable, Hashable, Sendable {
    /// The latest of them, whose book a tap opens.
    let lead: FeedEvent
    let others: [FeedEvent]

    var id: String { lead.id }
}

/// The friends' moves of one journal period, under its heading.
struct FriendSection: Identifiable, Hashable, Sendable {
    let title: String
    let moves: [FriendMove]
    var id: String { title }
}

/// A friend at the top of the Amis tab: lit while they moved since the reader
/// last looked.
struct FriendStory: Identifiable {
    let id: String
    let name: String
    let avatar: AccountAvatar
    let isNew: Bool
}

enum NewsFeedLayout {
    /// How far back "Sorti" reaches.
    static let releasedDays = 30

    /// What came out in the last thirty days among the series, the awaited
    /// editions and the narrators the reader follows, the newest first. A
    /// release dated to a month alone counts from its first day; one dated to a
    /// year, or not at all, is never "out lately".
    static func released(
        releases: [UpcomingRelease],
        narrator: [NarratorNews],
        format: BookFormat?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [ReleasedItem] {
        let today = calendar.startOfDay(for: now)
        guard let since = calendar.date(byAdding: .day, value: -releasedDays, to: today) else { return [] }
        let inWindow = { (day: Date) in day >= since && day <= today }
        var items: [ReleasedItem] = releases
            .filter { format == nil || $0.format == format }
            .compactMap { release in
                guard let day = day(of: release.date, calendar: calendar), inWindow(day) else { return nil }
                return .release(release, day: day)
            }
        let held = Set(items.compactMap { item -> String? in
            guard case let .release(release, _) = item else { return nil }
            return release.title.map { "\($0.lowercased())~\(release.format.rawValue)" }
        })
        if format == nil || format == .audiobook {
            items += narrator.compactMap { news in
                guard let day = day(of: news.date, calendar: calendar), inWindow(day),
                    !held.contains("\(news.title.lowercased())~\(BookFormat.audiobook.rawValue)")
                else { return nil }
                return .narrator(news, day: day)
            }
        }
        return items.sorted { $0.day > $1.day }
    }

    /// "Sorti" under the journal's periods, as Amis is: Aujourd'hui, Cette
    /// semaine, then the months.
    static func releasedSections(
        _ items: [ReleasedItem],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [ReleasedSection] {
        var sections: [(period: JournalPeriod, items: [ReleasedItem])] = []
        for item in items.sorted(by: { $0.day > $1.day }) {
            let period = JournalPeriod(item.day, now: now, calendar: calendar)
            if sections.last?.period != period { sections.append((period, [])) }
            sections[sections.count - 1].items.append(item)
        }
        return sections.map { ReleasedSection(title: $0.period.title(now: now, calendar: calendar), items: $0.items) }
    }

    /// `YYYY-MM-DD` or `YYYY-MM`; a bare year names no day.
    private static func day(of date: String?, calendar: Calendar) -> Date? {
        guard let date else { return nil }
        let parts = date.split(separator: "-").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts.count > 2 ? parts[2] : 1))
    }

    /// The friends' moves under their journal periods, newest first, narrowed
    /// to one friend when one is picked. Within a period the same move on the
    /// same story by several friends is one line.
    static func friendSections(
        events: [FeedEvent],
        friendId: String? = nil,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [FriendSection] {
        var sections: [(period: JournalPeriod, moves: [[FeedEvent]])] = []
        for event in events.sorted(by: { $0.at > $1.at }) where friendId == nil || event.friendId == friendId {
            let period = JournalPeriod(event.at, now: now, calendar: calendar)
            if sections.last?.period != period { sections.append((period, [])) }
            let last = sections.count - 1
            let key = sameMove(event)
            if let index = sections[last].moves.firstIndex(where: { sameMove($0[0]) == key }) {
                sections[last].moves[index].append(event)
            } else {
                sections[last].moves.append([event])
            }
        }
        return sections.map { section in
            FriendSection(
                title: section.period.title(now: now, calendar: calendar),
                moves: section.moves.map { FriendMove(lead: $0[0], others: Array($0.dropFirst())) }
            )
        }
    }

    /// Two friends' records of one story are two books: the move and the story
    /// tell them apart, not the record.
    private static func sameMove(_ event: FeedEvent) -> String {
        "\(event.kind.rawValue)~\(event.title.lowercased())~\(event.authors.first?.lowercased() ?? "")"
    }

    /// The friends who moved, the latest first, lit when they moved after `seenAt`.
    static func stories(events: [FeedEvent], seenAt: Date?) -> [FriendStory] {
        var stories: [FriendStory] = []
        for event in events.sorted(by: { $0.at > $1.at }) {
            let isNew = seenAt.map { event.at > $0 } ?? true
            if let index = stories.firstIndex(where: { $0.id == event.friendId }) {
                if isNew, !stories[index].isNew {
                    stories[index] = FriendStory(id: event.friendId, name: event.friendName, avatar: event.avatar, isNew: true)
                }
                continue
            }
            stories.append(FriendStory(id: event.friendId, name: event.friendName, avatar: event.avatar, isNew: isNew))
        }
        return stories
    }

    /// The formats the pills offer, in the board's order.
    static let pillFormats: [BookFormat] = [.book, .audiobook, .bandeDessinee, .comic, .manga]
}
