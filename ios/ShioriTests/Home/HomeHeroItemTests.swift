import Foundation
import Testing
@testable import Shiori

/// The carousel's line: what came out, then what comes out within the week,
/// then the discoveries, and how near each release is said.
struct HomeHeroItemTests {
    /// Wednesday 28 October 2026, at noon on the phone's calendar.
    private let today = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 12))!

    private func release(_ number: Int, _ date: String?) -> HomeRelease {
        let next = SagaDiscovery.preview.releases.next!
        let volume = DiscoveredVolume(number: number, title: next.title, date: date, isbn13: nil, coverURL: nil)
        return .volume(DiscoveryVolume(saga: .preview, volume: volume))
    }

    private func dates(_ items: [HomeHeroItem]) -> [String?] {
        items.compactMap { item in
            guard case let .release(release) = item else { return nil }
            return release.date
        }
    }

    @Test func outFirstNewestFirstThenThisMonthThenComing() {
        let releases = [
            release(1, "2026-11-02"),
            release(2, "2026-10-26"),
            release(3, "2026-10"),
            release(4, "2026-10-28"),
            release(5, "2026-10-29"),
            release(6, "2026-10-03"),
        ]
        let items = HomeHeroItem.items(releases: releases, discoveries: [], today: today)
        #expect(dates(items) == ["2026-10-28", "2026-10-26", "2026-10-03", "2026-10", "2026-10-29", "2026-11-02"])
    }

    @Test func leavesOutWhatIsTooFarOrUndated() {
        let releases = [
            release(1, "2026-11-04"),
            release(2, "2026-11"),
            release(3, "2027"),
            release(4, nil),
            release(5, "2026-09-30"),
        ]
        let items = HomeHeroItem.items(releases: releases, discoveries: [], today: today)
        #expect(dates(items) == [])
    }

    @Test func closesOnTheCallToRateWhenNothingIsRated() {
        let unrated = MonthlyDiscoveries(month: "2026-10", status: .none, suggestions: [], needsRatings: true)
        let items = HomeHeroItem.items(
            releases: [release(1, "2026-10-26")],
            discoveries: unrated.shownOnHome,
            doneMonth: unrated.doneMonth(today: today),
            needsRatingsMonth: unrated.needsRatingsMonth,
            today: today
        )
        #expect(items.map(\.id).last == "needs-ratings-2026-10")
        let rated = MonthlyDiscoveries(month: "2026-10", status: .none, suggestions: [])
        #expect(rated.needsRatingsMonth == nil)
    }

    @Test func keepsLastWeekAcrossTheTurnOfTheMonth() {
        let november = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 12))!
        let items = HomeHeroItem.items(
            releases: [release(1, "2026-10-29"), release(2, "2026-10-20")],
            discoveries: [],
            today: november
        )
        #expect(dates(items) == ["2026-10-29"])
    }

    @Test func leavesOutWhatWasSeen() {
        let seen = release(1, "2026-10-27")
        let items = HomeHeroItem.items(
            releases: [seen, release(2, "2026-10-28")],
            discoveries: [],
            seen: [seen.id],
            today: today
        )
        #expect(dates(items) == ["2026-10-28"])
    }

    @Test func discoveriesCloseTheLine() {
        let items = HomeHeroItem.items(
            releases: [release(1, "2026-10-30")],
            discoveries: MonthlyDiscoveries.preview.suggestions,
            today: today
        )
        guard case .release = items.first, case .discovery = items.last else {
            Issue.record("expected the release first and a discovery last")
            return
        }
    }

    @Test(arguments: [
        ("2026-10-28", "Sortie aujourd'hui"),
        ("2026-10-27", "Sortie hier"),
        ("2026-10-26", "Sortie avant-hier"),
        ("2026-10-23", "Sortie cette semaine"),
        ("2026-10-12", "Sortie ce mois-ci"),
        ("2026-10", "Sortie ce mois-ci"),
        ("2026-10-29", "Sortie demain"),
    ])
    func saysHowNear(date: String, badge: String) {
        #expect(HomeHeroItem.releaseBadge(date, today: today) == String(localized: String.LocalizationValue(badge)))
    }

    @Test func namesTheDayWithinTheWeek() {
        let tuesday = HomeHeroItem.releaseBadge("2026-11-03", today: today)
        let weekday = Calendar.current.date(byAdding: .day, value: 6, to: today)!.formatted(.dateTime.weekday(.wide))
        #expect(tuesday == String(localized: "Sortie \(weekday)"))
    }
}
