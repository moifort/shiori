import Foundation

/// One cover of a Découvrir shelf: the book, the short line in its foot, and
/// the person whose news it is — a friend, an author, a narrator — in a pill
/// on its top corner.
struct NewsShelfItem: Identifiable, Hashable, Sendable {
    let card: NewsCard
    /// "Tome 9 · 14 nov.", "Sorti · 12 oct.", "Annoncé · mars", "Il y a 3 jours".
    let caption: String
    /// The friend, the author or the narrator the pill names.
    var person: String?
    var portraitURL: URL?
    /// The friend's move: the pill then shows their face and names them by
    /// their first name, whole.
    var friend: FeedEvent?
    /// A friend's stars, drawn in place of the line.
    var rating: Double?
    /// Where a wish list edition out stands, "Sorti · 6 nov." or
    /// "Disponible": a large card's word, with no date leaf beside it.
    var standing: String?

    var id: String { card.id }

    /// The name in the pill: a friend's first name, "M. Wells" for an author.
    var pillName: String? {
        guard let person else { return nil }
        return friend == nil ? NewsPersonTile.shortName(person) : person
    }

    var avatar: AccountAvatar? { friend?.avatar }

    /// Where the pill leads: the Amis tab narrowed to the friend, the
    /// author's page, the narrator's. Nil when the card names no one it can
    /// open.
    var personTarget: NewsPersonTarget? {
        if let friend { return .friend(friend.friendId) }
        switch card {
        case let .released(.narrator(news, _)):
            return .narrator(NarratorDestination(key: news.narratorKey, name: news.narrator))
        case let .released(.release(release, _)), let .upcoming(release):
            switch UpcomingReleaseDestination.immediate(release) {
            case let .author(author): return .author(author)
            case let .narrator(narrator): return .narrator(narrator)
            default: return nil
            }
        default:
            return nil
        }
    }
}

/// The person a Découvrir card names, as its pill opens them.
enum NewsPersonTarget: Hashable {
    /// The Amis tab, showing that friend alone.
    case friend(String)
    case author(AuthorDestination)
    case narrator(NarratorDestination)
}

/// The shelves under Découvrir's agenda, each a rail of what one of the
/// reader's follows brought: what each friend did last, the friends'
/// favourites, the followed series, the favourite authors and narrators, the
/// wish list. Each runs newest first, then what is to come soonest first.
/// Pure: built from the same loads as the agenda.
struct NewsShelves: Hashable, Sendable {
    /// Each friend's latest move, however old, the most recent friend first.
    let activity: [NewsShelfItem]
    /// The friends' coups de cœur, newest first, each book once, how long ago
    /// in the foot.
    let loves: [NewsShelfItem]
    /// One card per followed series: its volume out lately, else its next.
    let series: [NewsShelfItem]
    /// The new books of the authors the reader hearted, out or announced.
    let authors: [NewsShelfItem]
    /// The new recordings of the narrators the reader follows.
    let narrators: [NewsShelfItem]
    /// The editions the reader awaits still to come: the dated soonest
    /// first, then the ones announced without a day.
    let wishes: [NewsShelfItem]

    /// How many covers a shelf shows at most.
    static let limit = 10

    static let empty = NewsShelves(activity: [], loves: [], series: [], authors: [], narrators: [], wishes: [])

    init(
        activity: [NewsShelfItem], loves: [NewsShelfItem], series: [NewsShelfItem], authors: [NewsShelfItem],
        narrators: [NewsShelfItem], wishes: [NewsShelfItem]
    ) {
        self.activity = activity
        self.loves = loves
        self.series = series
        self.authors = authors
        self.narrators = narrators
        self.wishes = wishes
    }

    /// - Parameters:
    ///   - released: what came out lately, newest first.
    ///   - moves: the friends' moves, newest first.
    ///   - upcoming: everything announced, dated or not.
    ///   - wishlist: the editions awaited the wish list rail shows, in the
    ///     server's order: to come, out lately, out already when asked for.
    init(
        released: [ReleasedItem], moves: [FriendMove], upcoming: [UpcomingRelease],
        wishlist: [UpcomingRelease] = [], today: Date, calendar: Calendar
    ) {
        let moves = moves.sorted { $0.lead.at > $1.lead.at }
        var seenFriends = Set<String>()
        activity = moves
            .filter { seenFriends.insert($0.lead.friendId).inserted }
            .prefix(Self.limit)
            .map { Self.friendItem($0, caption: Self.action($0.lead)) }
        var seenBooks = Set<String>()
        loves = moves
            .filter { $0.lead.kind == .loved && seenBooks.insert($0.lead.bookId).inserted }
            .prefix(Self.limit)
            .map { Self.friendItem($0, caption: Self.relative($0.lead.at, today: today, calendar: calendar), showsStars: false) }
        let out = released.sorted { $0.day > $1.day }
        // What is still to come, soonest first: a month or a year alone may
        // still be ahead, an exact day must be.
        let ahead = upcoming
            .filter { release in
                guard let day = NewsAgenda.exactDay(release.date, calendar: calendar) else { return true }
                return day > today
            }
            .sorted { ($0.date ?? "9999") < ($1.date ?? "9999") }

        func outRelease(_ source: ReleaseSource) -> [(UpcomingRelease, Date)] {
            out.compactMap { item in
                guard case let .release(release, day) = item, release.source == source else { return nil }
                return (release, day)
            }
        }
        func aheadRelease(_ source: ReleaseSource) -> [UpcomingRelease] {
            ahead.filter { $0.source == source }
        }

        // Series: one card each, the volume out lately before the next to come.
        var seenSeries = Set<String>()
        var seriesItems: [NewsShelfItem] = []
        for (release, day) in outRelease(.saga) where seenSeries.insert(release.seriesName ?? release.id).inserted {
            seriesItems.append(NewsShelfItem(
                card: .released(.release(release, day: day)),
                caption: Self.volumeTag(release, String(localized: "sorti"))
            ))
        }
        for release in aheadRelease(.saga) where seenSeries.insert(release.seriesName ?? release.id).inserted {
            seriesItems.append(NewsShelfItem(
                card: .upcoming(release),
                caption: Self.volumeTag(release, release.date.map { Self.shortDate($0, calendar: calendar) } ?? String(localized: "annoncé"))
            ))
        }
        series = Array(seriesItems.prefix(Self.limit))

        // Favourite authors: what they brought out lately, then what they announced.
        let favourite = { (release: UpcomingRelease) in release.author?.favorite == true }
        let authorItems = outRelease(.author).filter { favourite($0.0) }.map { release, day in
            NewsShelfItem(
                card: .released(.release(release, day: day)),
                caption: Self.outCaption(day),
                person: release.author?.name ?? release.authors.first,
                portraitURL: release.author?.portraitURL
            )
        } + aheadRelease(.author).filter(favourite).map { release in
            NewsShelfItem(
                card: .upcoming(release),
                caption: Self.announcedCaption(release.date, calendar: calendar),
                person: release.author?.name ?? release.authors.first,
                portraitURL: release.author?.portraitURL
            )
        }
        authors = Array(authorItems.prefix(Self.limit))

        // Narrators: their recordings out lately, then the ones announced.
        var narratorItems: [NewsShelfItem] = []
        for item in out {
            switch item {
            case let .narrator(news, day):
                narratorItems.append(NewsShelfItem(card: .released(item), caption: Self.outCaption(day), person: news.narrator))
            case let .release(release, day) where release.source == .narrator:
                narratorItems.append(NewsShelfItem(card: .released(item), caption: Self.outCaption(day), person: release.narrator))
            default:
                break
            }
        }
        narratorItems += aheadRelease(.narrator).map { release in
            NewsShelfItem(
                card: .upcoming(release),
                caption: Self.announcedCaption(release.date, calendar: calendar),
                person: release.narrator
            )
        }
        narrators = Array(narratorItems.prefix(Self.limit))

        // The wish list, as the server orders it: what is to come by its
        // date, what came out lately by its day, the rest found out already
        // when the reader asked for it.
        wishes = Array(wishlist.prefix(Self.limit).map { release in
            let (caption, isOut) = Self.wishCaption(release, today: today, calendar: calendar)
            return NewsShelfItem(card: .upcoming(release), caption: caption, standing: isOut ? caption : nil)
        })
    }

    /// "Tome 9 · 14 nov.", or the state alone outside a numbered series.
    static func volumeTag(_ release: UpcomingRelease, _ state: String) -> String {
        release.volume.map { String(localized: "Tome \($0) · \(state)") } ?? state.capitalizedFirst
    }

    /// A wish list edition's foot, and whether it is out: its date while to
    /// come, "Sorti · 6 nov." when out within the rail's thirty days,
    /// "Disponible" when it was out already as the reader asked for it.
    static func wishCaption(
        _ release: UpcomingRelease, today: Date, calendar: Calendar
    ) -> (caption: String, isOut: Bool) {
        let available = (String(localized: "Disponible"), true)
        guard let date = release.date else { return available }
        let parts = date.split(separator: "-").compactMap { Int($0) }
        guard parts.count > 1, let first = calendar.date(
            from: DateComponents(year: parts[0], month: parts[1], day: parts.count > 2 ? parts[2] : 1)
        ) else { return (shortDate(date, calendar: calendar), false) }
        let end = parts.count > 2 ? first : calendar.date(byAdding: .month, value: 1, to: first) ?? first
        guard end <= today else { return (shortDate(date, calendar: calendar), false) }
        let since = calendar.date(byAdding: .day, value: -NewsFeedLayout.releasedDays, to: today) ?? today
        return first >= since ? (outCaption(first), true) : available
    }

    /// "Sorti · 12 oct."
    static func outCaption(_ day: Date) -> String {
        String(localized: "Sorti · \(day.formatted(.dateTime.day().month(.abbreviated)))")
    }

    /// A friend's move as a cover: their face and first name in the pill.
    /// A finished book's stars are drawn in place of the line, unless
    /// `showsStars` is off: the favourites say how long ago instead.
    static func friendItem(_ move: FriendMove, caption: String, showsStars: Bool = true) -> NewsShelfItem {
        let event = move.lead
        let stars = showsStars && event.kind == .finished ? event.rating.flatMap { $0 > 0 ? $0 : nil } : nil
        return NewsShelfItem(
            card: .friend(move), caption: caption, person: event.friendName, friend: event, rating: stars
        )
    }

    /// What a friend did, in the cover's foot: "♥ Adoré", "Commencé",
    /// "Terminé" (their stars drawn instead when they gave any).
    static func action(_ event: FeedEvent) -> String {
        switch event.kind {
        case .loved: "\u{2665}\u{FE0E} " + String(localized: "Adoré")
        case .started: String(localized: "Commencé")
        case .finished: String(localized: "Terminé")
        }
    }

    /// How long ago, in words a glance reads: "Aujourd'hui", "Hier", "Il y a
    /// 3 jours", "Il y a 2 semaines", "Il y a 1 mois", "Il y a 1 an".
    static func relative(_ date: Date, today: Date, calendar: Calendar) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: today).day ?? 0
        guard days > 0 else { return String(localized: "Aujourd'hui") }
        let ago: DateComponents = switch days {
        case ..<7: DateComponents(day: -days)
        case ..<30: DateComponents(weekOfMonth: -(days / 7))
        case ..<365: DateComponents(month: -(days / 30))
        default: DateComponents(year: -(days / 365))
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        // "Hier" by name; past it, a count: "Il y a 1 an", not "L'année dernière".
        formatter.dateTimeStyle = days == 1 ? .named : .numeric
        formatter.unitsStyle = .full
        return formatter.localizedString(from: ago).capitalizedFirst
    }

    /// Any card of the page as a cover of a rail: the agenda's day and the
    /// headlines draw their books as the shelves do.
    static func item(_ card: NewsCard, calendar: Calendar) -> NewsShelfItem {
        switch card {
        case let .friend(move):
            return friendItem(move, caption: action(move.lead))
        case let .released(.release(release, day)):
            switch release.source {
            case .saga:
                return NewsShelfItem(card: card, caption: release.volume.map { String(localized: "Tome \($0)") } ?? String(localized: "Sorti"))
            case .awaited:
                return NewsShelfItem(card: card, caption: volumeTag(release, String(localized: "sorti")))
            case .author:
                return NewsShelfItem(
                    card: card, caption: outCaption(day), person: release.author?.name ?? release.authors.first,
                    portraitURL: release.author?.portraitURL
                )
            case .narrator:
                return NewsShelfItem(card: card, caption: outCaption(day), person: release.narrator)
            }
        case let .released(.narrator(news, day)):
            return NewsShelfItem(card: card, caption: outCaption(day), person: news.narrator)
        case let .upcoming(release):
            let date = release.date.map { shortDate($0, calendar: calendar) }
            switch release.source {
            case .saga, .awaited:
                return NewsShelfItem(card: card, caption: volumeTag(release, date ?? String(localized: "annoncé")))
            case .author:
                return NewsShelfItem(
                    card: card, caption: announcedCaption(release.date, calendar: calendar),
                    person: release.author?.name ?? release.authors.first, portraitURL: release.author?.portraitURL
                )
            case .narrator:
                return NewsShelfItem(card: card, caption: announcedCaption(release.date, calendar: calendar), person: release.narrator)
            }
        case .suggestion, .award:
            return NewsShelfItem(card: card, caption: NewsCardText.label(card, long: false))
        }
    }

    /// "Annoncé · 14 nov.", "Annoncé · mars", "Annoncé".
    static func announcedCaption(_ date: String?, calendar: Calendar) -> String {
        guard let date else { return String(localized: "Annoncé") }
        return String(localized: "Annoncé · \(shortDate(date, calendar: calendar))")
    }

    /// "14 nov.", "mars", "2027", from `YYYY-MM-DD`, `YYYY-MM` or `YYYY`.
    static func shortDate(_ date: String, calendar: Calendar) -> String {
        let parts = date.split(separator: "-").compactMap { Int($0) }
        guard let year = parts.first else { return date }
        guard parts.count > 1, let day = calendar.date(from: DateComponents(
            year: year, month: parts[1], day: parts.count > 2 ? parts[2] : 1
        )) else { return String(year) }
        return parts.count > 2
            ? day.formatted(.dateTime.day().month(.abbreviated))
            : day.formatted(.dateTime.month(.wide))
    }
}

private extension String {
    /// "sorti" → "Sorti", where the state stands alone.
    var capitalizedFirst: String {
        guard let head = first else { return self }
        return String(head).localizedUppercase + dropFirst()
    }
}

extension NewsShelfItem {
    /// A large card's word on the foot of its cover: what happened, without
    /// the day the date leaf says — "♥ Adoré", "Tome 9", "Sorti", "Annoncé",
    /// "À paraître".
    var word: String {
        if let standing { return standing }
        switch card {
        case let .friend(move):
            return NewsShelves.action(move.lead)
        case let .released(.release(release, _)):
            if release.source == .saga, let volume = release.volume { return String(localized: "Tome \(volume)") }
            return String(localized: "Sorti")
        case .released(.narrator):
            return String(localized: "Sorti")
        case let .upcoming(release):
            switch release.source {
            case .saga: return release.volume.map { String(localized: "Tome \($0)") } ?? String(localized: "Annoncé")
            case .awaited: return release.date == nil ? String(localized: "En vue") : String(localized: "À paraître")
            case .author, .narrator: return String(localized: "Annoncé")
            }
        case .suggestion, .award:
            return caption
        }
    }

    /// The card's day, as `YYYY-MM-DD` — or `YYYY-MM`, `YYYY` for what is
    /// announced that loosely: when a release came or comes out, when a
    /// friend made their move. The date leaf in the corner, past days
    /// included since the page is news, and how long is left when ahead.
    /// Nil for the prizes, the month's discovery and what has no date.
    var day: String? {
        if standing != nil { return nil }
        return switch card {
        case let .released(item): Self.isoDay(item.day)
        case let .upcoming(release): release.date
        case let .friend(move): Self.isoDay(move.lead.at)
        case .suggestion, .award: nil
        }
    }

    /// An edition the reader awaits already: its card says it is in the wish
    /// list rather than offering it.
    var isAwaited: Bool {
        if case let .upcoming(release) = card { return release.source == .awaited }
        return false
    }

    static func isoDay(_ day: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 1, parts.day ?? 1)
    }
}
