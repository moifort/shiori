import Foundation
import Testing
@testable import Shiori

/// Tuesday 27 October 2026, noon, in Paris.
private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
    return calendar
}()
private let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 27, hour: 12))!
private func daysAgo(_ days: Int) -> Date { calendar.date(byAdding: .day, value: -days, to: now)! }

private func book(
    _ id: String,
    format: BookFormat = .book,
    genre: BookGenre? = nil,
    waited days: Int = 0,
    status: ReadingStatus = .toRead
) -> Book {
    var book = Book(id: id, title: id, authors: ["Frank Herbert"], status: status)
    book.format = format
    book.genre = genre
    book.shelvedAt = daysAgo(days)
    return book
}

struct PileLabelTests {
    private func caption(_ kind: PileSectionKind, _ pick: PilePick) -> String {
        PileSection(kind: kind, picks: [pick]).label(of: pick, now: now, calendar: calendar).caption
    }

    @Test func eachSectionSaysWhyTheBookIsThere() {
        var next = book("rr6")
        next.series = SeriesMembership(id: "rr", name: "Red Rising", volume: 6, kind: .main)
        var advised = book("piranesi")
        advised.recommendation = BookRecommendation(recommenderName: "Julie Martin")
        var heard = book("silo", format: .audiobook)
        heard.narrators = ["Tim Gerard Reynolds"]

        #expect(caption(.nextVolume, PilePick(book: next)) == next.series?.label)
        #expect(caption(.recommended, PilePick(book: advised)) == String(localized: "Par \("Julie")"))
        #expect(caption(.newAuthors, PilePick(book: book("dune"))) == "Herbert")
        #expect(caption(.favoriteNarrators, PilePick(book: heard)) == "Reynolds")
        #expect(caption(.awarded, PilePick(book: book("dune"), award: AwardMention(award: .hugo, year: 1966))) == "Hugo 1966")
    }

    @Test func aBookToFinishSaysItAsTheLibraryDoes() {
        var open = book("fondation", status: .reading)
        open.startedAt = daysAgo(6)
        var heard = book("hail-mary", format: .audiobook, status: .reading)
        heard.listeningProgress = 74

        let paper = PileSection(kind: .toFinish, picks: []).label(of: PilePick(book: open), now: now, calendar: calendar)
        let audio = PileSection(kind: .toFinish, picks: []).label(of: PilePick(book: heard), now: now, calendar: calendar)

        #expect(paper.caption == String(localized: "depuis \(6)j"))
        #expect(paper.marksReading)
        #expect(audio.caption == "74%")
        #expect(audio.progress == 74)
    }

    @Test func aSurnameKeepsItsParticles() {
        #expect(PileSection.surname("Ursula K. Le Guin") == "Le Guin")
        #expect(PileSection.surname("A. E. van Vogt") == "van Vogt")
        #expect(PileSection.surname("Frank Herbert") == "Herbert")
        #expect(PileSection.surname("Moebius") == "Moebius")
    }
}

@MainActor
struct PileViewModelTests {
    @Test func keepsThePillsWhenAGenreIsChosen() async {
        let client = LibraryClient(pile: { view in
            Pile(genres: view.genre == nil ? [.fantasy, .scienceFiction] : [.fantasy])
        })
        let viewModel = PileViewModel(client: client, caching: false)

        await viewModel.load()
        await viewModel.select(genre: .fantasy)

        #expect(viewModel.shownGenres == [.fantasy, .scienceFiction])
        #expect(viewModel.view.genre == .fantasy)
    }

    @Test func aGenrePageOffersNoGenrePills() async {
        let client = LibraryClient(pile: { _ in Pile(genres: [.fantasy, .scienceFiction]) })
        let viewModel = PileViewModel(client: client, view: ShelvesView(genre: .fantasy), caching: false)

        await viewModel.load()

        #expect(viewModel.shownGenres.isEmpty)
    }

    @Test func aFailureOverSectionsKeepsThem() async {
        let fails = Flag()
        let client = LibraryClient(pile: { _ in
            if fails.isOn { throw Boom() }
            return Pile(sections: [PileSection(kind: .toFinish, picks: [PilePick(book: book("a", status: .reading))])])
        })
        let viewModel = PileViewModel(client: client, caching: false)

        await viewModel.load()
        fails.isOn = true
        await viewModel.load()

        #expect(viewModel.pile.sections.map(\.kind) == [.toFinish])
    }
}
