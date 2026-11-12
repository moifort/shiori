import Foundation

/// One cover of a Découvrir shelf: the book, the short line said of it, and
/// for an author's or a narrator's shelf the person whose news it is.
struct NewsShelfItem: Identifiable, Hashable, Sendable {
    let card: NewsCard
    /// "Tome 9 · 14 nov.", "Sorti le 12 oct.", "Annoncé · mars", "Sorti".
    let caption: String
    /// The author or the narrator, on their shelves.
    var person: String?
    var portraitURL: URL?

    var id: String { card.id }
}

/// The shelves under Découvrir's agenda, each a rail of what one of the
/// reader's follows brought: the friends' recent favourites, the followed
/// series, the favourite authors and narrators, the wish list. Pure: built
/// from the same loads as the agenda.
struct NewsShelves: Hashable, Sendable {
    /// The friends' recent coups de cœur, newest first, each book once.
    let loves: [FriendMove]
    /// One card per followed series: its volume out lately, else its next.
    let series: [NewsShelfItem]
    /// The new books of the authors the reader hearted, out or announced.
    let authors: [NewsShelfItem]
    /// The new recordings of the narrators the reader follows.
    let narrators: [NewsShelfItem]
    /// The editions the reader awaits, out or announced.
    let wishes: [NewsShelfItem]

    /// How many covers a shelf shows at most.
    static let limit = 10

    static let empty = NewsShelves(loves: [], series: [], authors: [], narrators: [], wishes: [])

    init(loves: [FriendMove], series: [NewsShelfItem], authors: [NewsShelfItem], narrators: [NewsShelfItem], wishes: [NewsShelfItem]) {
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
    init(released: [ReleasedItem], moves: [FriendMove], upcoming: [UpcomingRelease], today: Date, calendar: Calendar) {
        var seenBooks = Set<String>()
        loves = Array(
            moves.filter { $0.lead.kind == .loved && seenBooks.insert($0.lead.bookId).inserted }.prefix(Self.limit)
        )
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

        // The wish list: what came out, then what is announced.
        let wishItems = outRelease(.awaited).map { release, day in
            NewsShelfItem(card: .released(.release(release, day: day)), caption: String(localized: "Sorti"))
        } + aheadRelease(.awaited).map { release in
            NewsShelfItem(
                card: .upcoming(release),
                caption: release.date.map { Self.shortDate($0, calendar: calendar) } ?? String(localized: "En vue")
            )
        }
        wishes = Array(wishItems.prefix(Self.limit))
    }

    /// "Tome 9 · 14 nov.", or the state alone outside a numbered series.
    static func volumeTag(_ release: UpcomingRelease, _ state: String) -> String {
        release.volume.map { String(localized: "Tome \($0) · \(state)") } ?? state.capitalizedFirst
    }

    /// "Sorti le 12 oct."
    static func outCaption(_ day: Date) -> String {
        String(localized: "Sorti le \(day.formatted(.dateTime.day().month(.abbreviated)))")
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
