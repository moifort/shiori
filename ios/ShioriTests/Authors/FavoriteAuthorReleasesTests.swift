import Foundation
import Testing
@testable import Shiori

struct FavoriteAuthorReleasesTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    /// Tuesday 10 November 2026, noon UTC.
    private let now = Date(timeIntervalSince1970: 1_794_312_000)

    private func release(
        _ id: String,
        by author: String,
        on date: String?,
        source: ReleaseSource = .saga,
        hearted: Bool? = nil
    ) -> UpcomingRelease {
        UpcomingRelease(
            id: id, source: source, format: .book, title: id, authors: [author], date: date, coverURL: nil,
            seriesName: nil, volume: nil,
            author: hearted.map { .init(key: id, name: author, favorite: $0, portraitURL: nil) },
            sagaRating: nil, sagaFavorite: false
        )
    }

    private func ids(_ releases: [UpcomingRelease], favorites: [String]) -> [String] {
        FavoriteAuthorReleases.of(releases, favorites: favorites, today: now, calendar: calendar).map(\.id)
    }

    @Test func keepsTheHeartedAuthorsInTheServerOrder() {
        let releases = [
            release("light-bringer", by: "Pierce Brown", on: "2026-12-18"),
            release("expanse", by: "James S. A. Corey", on: "2027-01-15"),
            release("piranesi-2", by: "Susanna Clarke", on: "2027-03", source: .author, hearted: true),
            release("weir", by: "Andy Weir", on: nil, source: .author, hearted: false),
        ]
        #expect(ids(releases, favorites: ["Pierce Brown"]) == ["light-bringer", "piranesi-2"])
    }

    @Test func matchesANameWhateverItsCaseAndAccents() {
        let releases = [release("tome-5", by: "Herve Le Corre", on: "2027")]
        #expect(ids(releases, favorites: ["Hervé le Corre"]) == ["tome-5"])
    }

    @Test func dropsWhatIsAlreadyOutButKeepsThisMonthAndTheUndated() {
        let releases = [
            release("out", by: "Pierce Brown", on: "2026-11-04"),
            release("today", by: "Pierce Brown", on: "2026-11-10"),
            release("this-month", by: "Pierce Brown", on: "2026-11"),
            release("last-year", by: "Pierce Brown", on: "2025"),
            release("undated", by: "Pierce Brown", on: nil),
        ]
        #expect(ids(releases, favorites: ["Pierce Brown"]) == ["today", "this-month", "undated"])
    }

    @Test func leavesTheNarratorsRecordingsAndDuplicatesOut() {
        let releases = [
            release("voice", by: "Pierce Brown", on: "2026-12-01", source: .narrator),
            release("twice", by: "Pierce Brown", on: "2026-12-02"),
            release("twice", by: "Pierce Brown", on: "2026-12-02"),
        ]
        #expect(ids(releases, favorites: ["Pierce Brown"]) == ["twice"])
    }

    @Test func showsNothingWithoutAHeartedAuthor() {
        #expect(ids([release("a", by: "Pierce Brown", on: "2027")], favorites: []).isEmpty)
    }
}
