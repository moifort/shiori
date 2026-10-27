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

struct WholePileTests {
    private let pile = [
        book("dune", format: .audiobook, genre: .scienceFiction, waited: 0),
        book("frieren", format: .manga, genre: .fantasy, waited: 3),
        book("circe", genre: .fantasy, waited: 60),
        book("expanse", genre: .scienceFiction, waited: 500),
        book("1984", genre: .literaryFiction, waited: 1500),
        book("sapiens", waited: 40),
    ]

    private func outline(_ grouping: PileGrouping) -> [String] {
        WholePile.sections(pile, by: grouping, now: now, calendar: calendar).map { section in
            "\(section.title): \(section.rows.map(\.id).joined(separator: ","))"
        }
    }

    @Test func byDateTheNewestSpanComesFirst() {
        #expect(outline(.date) == [
            "\(String(localized: "Ce mois-ci")): dune,frieren",
            "\(String(localized: "Moins d'un an")): circe,sapiens",
            "\(String(localized: "1 à 2 ans")): expanse",
            "\(String(localized: "Plus de 2 ans")): 1984",
        ])
    }

    @Test func byFormatTheFormatsComeInTheAppsOrder() {
        #expect(outline(.format) == [
            "\(BookFormat.book.shelfLabel): circe,expanse,1984,sapiens",
            "\(BookFormat.audiobook.shelfLabel): dune",
            "\(BookFormat.manga.shelfLabel): frieren",
        ])
    }

    @Test func byGenreTheFullestComesFirstAndABookWithoutOneIsOther() {
        // Two each for fantasy and science fiction, one each for the rest: the label breaks a tie.
        #expect(outline(.genre) == [
            "\(BookGenre.fantasy.label): frieren,circe",
            "\(BookGenre.scienceFiction.label): dune,expanse",
            "\(BookGenre.other.label): sapiens",
            "\(BookGenre.literaryFiction.label): 1984",
        ])
    }

    @Test func aCoverSaysWhatItsHeadingDoesNot() {
        let dune = pile[0]

        #expect(WholePile.label(of: dune, by: .date, now: now, calendar: calendar).caption == BookGenre.scienceFiction.shortLabel)
        #expect(WholePile.label(of: dune, by: .format, now: now, calendar: calendar).caption == BookGenre.scienceFiction.shortLabel)
        #expect(WholePile.label(of: dune, by: .genre, now: now, calendar: calendar).caption == PosterLabel.waited(daysAgo(0), now: now, calendar: calendar))
        #expect(WholePile.label(of: pile[5], by: .date, now: now, calendar: calendar).caption == PosterLabel.waited(daysAgo(40), now: now, calendar: calendar))
    }
}

@MainActor
struct PileViewModelTests {
    @Test func keepsThePillsWhenAFormatIsChosen() async {
        let client = LibraryClient(pile: { view in
            Pile(
                formats: view.format == nil ? [.book, .manga] : [.manga],
                sections: [PileSection(kind: .newAuthors, picks: [PilePick(book: book("frieren", format: .manga))])]
            )
        })
        let viewModel = PileViewModel(client: client, caching: false)

        await viewModel.load()
        await viewModel.select(format: .manga)

        #expect(viewModel.shownFormats == [.book, .manga])
        #expect(viewModel.view.format == .manga)
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

    @Test func aFormatChosenBeforeOffersNoPills() async {
        let client = LibraryClient(pile: { _ in Pile(formats: [.book, .manga]) })
        let viewModel = PileViewModel(client: client, view: ShelvesView(format: .manga), caching: false)

        await viewModel.load()

        #expect(viewModel.shownFormats.isEmpty)
    }
}
