import Foundation

/// "Prochaines sorties" on the Narrators shelf: the recordings announced for the
/// narrators the reader hearted. The server finds them only for the hearted
/// narrators, off the narrator watches, so nothing is matched here: the
/// narrators' releases are kept, those gone by and the repeats left out.
enum FavoriteNarratorReleases {
    /// The narrators' releases still ahead, in the server's order: the soonest
    /// first, the undated last.
    static func of(
        _ releases: [UpcomingRelease],
        today: Date = .now,
        calendar: Calendar = .current
    ) -> [UpcomingRelease] {
        var seen = Set<String>()
        let narrated = releases.filter { $0.source == .narrator && seen.insert($0.id).inserted }
        return FavoriteAuthorReleases.stillAhead(narrated, today: today, calendar: calendar)
    }
}
