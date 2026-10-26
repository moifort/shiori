import Foundation
import Testing
@testable import Shiori

/// Monday 26 October 2026, noon, on a French calendar: the week starts on Monday.
private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "fr_FR")
    calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
    calendar.firstWeekday = 2
    return calendar
}()
private let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 12))!
private func daysAgo(_ days: Int) -> Date { calendar.date(byAdding: .day, value: -days, to: now)! }

private func book(_ id: String, _ status: ReadingStatus, shelved days: Int) -> Book {
    var book = Book(id: id, title: id, authors: ["Auteur"], status: status)
    book.shelvedAt = daysAgo(days)
    return book
}

struct PosterLabelTests {
    @Test func thePileSaysHowLongABookHasWaited() {
        #expect(PosterLabel.waited(daysAgo(0), now: now, calendar: calendar) == "Aujourd'hui")
        #expect(PosterLabel.waited(daysAgo(1), now: now, calendar: calendar) == "Hier")
        #expect(PosterLabel.waited(daysAgo(10), now: now, calendar: calendar) == "10 jours")
        #expect(PosterLabel.waited(daysAgo(21), now: now, calendar: calendar) == "3sem.")
        #expect(PosterLabel.waited(daysAgo(65), now: now, calendar: calendar) == "2 mois")
        #expect(PosterLabel.waited(daysAgo(400), now: now, calendar: calendar) == "1 an")
    }

    @Test func aPaperBookBeingReadWearsTheBookmarkAndNoPercentage() {
        let label = PosterLabel.of(book("p", .reading, shelved: 6), in: .recent, now: now, calendar: calendar)

        #expect(label.caption == "depuis 6j")
        #expect(label.marksReading)
        #expect(label.progress == nil)
    }

    @Test func aRecordingBeingHeardShowsItsBarAndPercentage() {
        var heard = book("a", .reading, shelved: 2)
        heard.listeningProgress = 68

        let label = PosterLabel.of(heard, in: .recent, now: now, calendar: calendar)

        #expect(label.caption == "68%")
        #expect(label.progress == 68)
        #expect(label.marksReading)
    }

    @Test func aFavouriteIsFiveStarsNeverAHeart() {
        var loved = book("f", .read, shelved: 3)
        loved.favorite = true
        loved.rating = 3

        #expect(PosterLabel.of(loved, in: .read, now: now, calendar: calendar).caption == "★★★★★")
    }

    @Test func aBookReadAndUnratedSaysWhen() {
        #expect(PosterLabel.of(book("r", .read, shelved: 1), in: .read, now: now, calendar: calendar).caption == "Lu hier")
    }

    @Test func aBookGivenUpOnIsDimmed() {
        let label = PosterLabel.of(book("d", .dropped, shelved: 30), in: .recent, now: now, calendar: calendar)

        #expect(label.caption == "Abandonné")
        #expect(label.dimming == PosterLabel.setAsideDimming)
    }

    @Test func halfStarsAreKept() {
        #expect(PosterLabel.stars(3.5) == "★★★½")
        #expect(PosterLabel.stars(4) == "★★★★")
    }
}

struct JournalSectionTests {
    @Test func aShelfIsCutAsAJournalReadsBack() {
        let rows = [
            book("today", .toRead, shelved: 0),
            book("yesterday", .toRead, shelved: 1),
            book("lastWeek", .toRead, shelved: 4),
            book("earlier", .toRead, shelved: 15),
            book("september", .toRead, shelved: 40),
            book("lastYear", .toRead, shelved: 300),
        ]

        let titles = ListSection.byPeriod(rows, on: \.shelvedAt, now: now, calendar: calendar).map(\.title)

        #expect(titles.count == 6)
        #expect(titles[0] == "Aujourd'hui")
        #expect(titles[1] == "Hier")
        #expect(titles[2] == "La semaine dernière")
        #expect(titles[3].hasPrefix("Plus tôt en"))
        #expect(titles[5].contains("2025"))
    }

    @Test func theFavouritesAreCutByYear() {
        let rows = [book("a", .read, shelved: 2), book("b", .read, shelved: 400)]

        #expect(ListSection.byYear(rows, on: \.shelvedAt, calendar: calendar).map(\.title) == ["2026", "2025"])
    }
}

struct SeriesShelfTests {
    private func saga(owned: [ReadingStatus], published: Int, announced: Bool = false) -> FollowedSeries {
        let books = owned.enumerated().map { index, status in
            var book = Book(id: "v\(index + 1)", title: "Tome \(index + 1)", authors: [], status: status)
            book.series = SeriesMembership(id: "s", name: "Série", volume: index + 1, kind: .main)
            return book
        }
        var strip = books.map { SeriesStripItem.owned($0) }
        for number in (owned.count + 1)...max(owned.count + 1, published) where number <= published {
            strip.append(.missing(key: "m\(number)", number: number, title: "Tome \(number)", forthcoming: false))
        }
        if announced {
            strip.append(.missing(key: "next", number: published + 1, title: "À venir", forthcoming: true, date: "2027-03"))
        }
        return FollowedSeries(
            seriesId: "s", name: "Série", author: nil, language: nil,
            state: .inProgress, genre: nil, ownedCount: books.count, volumes: books, strip: strip
        )
    }

    @Test func countsTheVolumesOutAndRead() {
        let series = saga(owned: [.read, .read, .toRead], published: 5, announced: true)

        #expect(series.readCount == 2)
        #expect(series.totalCount == 5)
        #expect(series.missingCount == 2)
    }

    @Test func theNextVolumeIsTheOneOpenElseTheFirstLacking() {
        #expect(saga(owned: [.read, .reading, .toRead], published: 3).nextVolume == .owned(saga(owned: [.read, .reading, .toRead], published: 3).volumes[1]))
        if case let .missing(number, _, _) = saga(owned: [.read, .read], published: 4).nextVolume {
            #expect(number == 3)
        } else {
            Issue.record("expected the first volume lacking")
        }
    }

    @Test func theNextReleaseIsTheVolumeAnnounced() {
        #expect(saga(owned: [.read], published: 1, announced: true).nextRelease?.date == "2027-03")
        #expect(saga(owned: [.read], published: 1).nextRelease == nil)
    }

    @Test func aFilterIsOfferedOnlyWhenItHoldsASaga() {
        let offered = SeriesShelfFilter.offered(for: [saga(owned: [.read], published: 3)])

        #expect(offered.contains(.all))
        #expect(offered.contains(.inProgress))
        #expect(offered.contains(.incomplete))
        #expect(!offered.contains(.complete))
    }
}

@MainActor
struct BookShelfViewModelTests {
    private func serving(_ books: [Book], asked: Calls? = nil) -> LibraryClient {
        var client = LibraryClient()
        client.shelf = { query, limit, after in
            asked?.record(query.serverStatus?.rawValue ?? "all")
            let kept = books.filter { query.serverStatus == nil || $0.status == query.serverStatus }
            let start = after.flatMap { id in kept.firstIndex { $0.id == id }.map { $0 + 1 } } ?? 0
            let page = Array(kept.dropFirst(start).prefix(limit))
            return LibraryPageResult(books: page, hasMore: start + page.count < kept.count)
        }
        return client
    }

    @Test func recentlyStopsSixMonthsBack() async {
        let books = [book("new", .toRead, shelved: 3), book("old", .read, shelved: 250)]
        let viewModel = BookShelfViewModel(client: serving(books), shelf: .recent, now: { now })

        await viewModel.load()

        #expect(viewModel.books.map(\.id) == ["new"])
        #expect(viewModel.hasMore == false)
    }

    @Test func aStatusPillNarrowsRecently() async {
        let asked = Calls()
        let books = [book("a", .toRead, shelved: 1), book("b", .reading, shelved: 2)]
        let viewModel = BookShelfViewModel(client: serving(books, asked: asked), shelf: .recent, status: .reading, now: { now })

        await viewModel.load()

        #expect(viewModel.books.map(\.id) == ["b"])
        #expect(asked.all == ["reading"])
    }

    @Test func aBookFinishedLeavesThePile() async {
        let viewModel = BookShelfViewModel(client: serving([book("a", .toRead, shelved: 1)]), shelf: .toRead, now: { now })
        await viewModel.load()

        viewModel.apply(book("a", .reading, shelved: 0))

        #expect(viewModel.books.isEmpty)
    }

    @Test func formatPillsShowOnlyWithTwoFormats() async {
        var manga = book("m", .toRead, shelved: 1)
        manga.format = .manga
        let viewModel = BookShelfViewModel(client: serving([book("a", .toRead, shelved: 0), manga]), shelf: .toRead, now: { now })

        await viewModel.load()

        #expect(viewModel.shownFormats == [.book, .manga])
    }
}
