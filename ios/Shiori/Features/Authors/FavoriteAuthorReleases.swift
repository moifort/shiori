import Foundation

/// "Prochaines sorties" on the Authors shelf: what the authors the reader
/// hearted have announced, picked out of everything announced across their
/// follows. A saga's volume names its author only by name, so the hearted
/// authors' names are matched too, not just the author an announcement carries.
enum FavoriteAuthorReleases {
    /// The releases still ahead whose author the reader hearted, in the
    /// server's order: the soonest first, the undated last. A recording found
    /// for a narrator stays out: it belongs to the narrator's news.
    static func of(
        _ releases: [UpcomingRelease],
        favorites: [String],
        today: Date = .now,
        calendar: Calendar = .current
    ) -> [UpcomingRelease] {
        let hearted = Set(favorites.map(folded))
        let day = isoDay(today, calendar: calendar)
        var seen = Set<String>()
        return releases.filter { release in
            guard release.source != .narrator, !isPast(release.date, today: day) else { return false }
            let byFavorite = release.author?.favorite == true
                || release.authors.contains { hearted.contains(folded($0)) }
            return byFavorite && seen.insert(release.id).inserted
        }
    }

    /// A date announced before today: `YYYY-MM-DD`, `YYYY-MM` or `YYYY`,
    /// each compared at its own precision, so this month or this year still
    /// counts as ahead.
    static func isPast(_ date: String?, today: String) -> Bool {
        guard let date, !date.isEmpty else { return false }
        return date < today.prefix(date.count)
    }

    private static func folded(_ name: String) -> String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespaces)
    }

    private static func isoDay(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
