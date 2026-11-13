import Foundation
import Testing
@testable import Shiori

struct FavoriteNarratorReleasesTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    /// Tuesday 10 November 2026, noon UTC.
    private let now = Date(timeIntervalSince1970: 1_794_312_000)

    private func release(_ id: String, on date: String?, source: ReleaseSource) -> UpcomingRelease {
        UpcomingRelease(
            id: id, source: source, format: .audiobook, title: id, authors: ["Dan Simmons"], date: date,
            coverURL: nil, seriesName: nil, volume: nil, author: nil, sagaRating: nil, sagaFavorite: false
        )
    }

    @Test func keepsTheNarratorsRecordingsStillAheadOnce() {
        let releases = [
            release("saga", on: "2026-12-01", source: .saga),
            release("gone-by", on: "2026-11-04", source: .narrator),
            release("ahead", on: "2026-12", source: .narrator),
            release("ahead", on: "2026-12", source: .narrator),
            release("author", on: "2027", source: .author),
        ]
        let kept = FavoriteNarratorReleases.of(releases, today: now, calendar: calendar)
        #expect(kept.map(\.id) == ["ahead"])
    }
}
