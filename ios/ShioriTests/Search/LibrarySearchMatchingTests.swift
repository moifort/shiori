import Foundation
import Testing
@testable import Shiori

private func volume(_ number: Int, _ title: String, status: ReadingStatus = .read, favorite: Bool = false) -> Book {
    var book = Book(id: "dcc\(number)", title: title, authors: ["Matt Dinniman"], status: status)
    book.series = SeriesMembership(id: "dcc", name: "Dungeon Crawler Carl", volume: number, kind: .main)
    book.favorite = favorite
    return book
}

private let library: [SearchEntry] = [
    volume(1, "Dungeon Crawler Carl"),
    volume(2, "Carl's Doomsday Scenario"),
    volume(5, "The Butcher's Masquerade", status: .reading),
    {
        var book = Book(id: "assassin", title: "L'Assassin royal", authors: ["Robin Hobb"], status: .toRead)
        book.favorite = true
        return book
    }(),
    Book(id: "eve", title: "Ève", authors: [], status: .read),
    Book(id: "card", title: "Card Sharks", authors: ["Someone Else"], status: .read),
].map(SearchEntry.init)

private func titles(_ query: String, filter: SearchFilter = SearchFilter()) -> [String] {
    LibrarySearchMatcher.results(for: query, in: library, filter: filter).books.map(\.title)
}

struct LibrarySearchMatchingTests {
    @Test func normalizesCaseAccentsAndPunctuation() {
        #expect(SearchText.normalized("L'Assassin  Royal") == "l assassin royal")
        #expect(SearchText.normalized("Ève — Tome 2 : la fin") == "eve tome 2 la fin")
    }

    @Test func findsAWordFromItsStart() {
        // Every volume of the saga, by its saga's name, the title match first.
        #expect(titles("dung") == ["Dungeon Crawler Carl", "Carl's Doomsday Scenario", "The Butcher's Masquerade"])
        #expect(titles("assas") == ["L'Assassin royal"])
        #expect(titles("eve") == ["Ève"])
    }

    @Test func forgivesOneLetterInALongWord() {
        // The volume named by its title first, then those found by their saga.
        #expect(titles("dungeon crawler card") == [
            "Dungeon Crawler Carl",
            "Carl's Doomsday Scenario",
            "The Butcher's Masquerade",
        ])
        #expect(titles("crawlr").first == "Dungeon Crawler Carl")
        #expect(titles("crawlr").count == 3)
    }

    @Test func forgivesNothingInAShortWord() {
        #expect(titles("evx").isEmpty)
    }

    @Test func findsAVolumeByItsNumber() {
        #expect(titles("carl 5") == ["The Butcher's Masquerade"])
    }

    @Test func ranksTitleMatchesBeforeAuthorMatches() {
        // "card" is Card Sharks' title, and only one letter off Carl.
        #expect(titles("card").first == "Card Sharks")
    }

    @Test func requiresEveryWord() {
        #expect(titles("dungeon hobb").isEmpty)
    }

    @Test func blankQueryIsEmptyUnlessAFilterIsOn() {
        #expect(titles("  ' ").isEmpty)
        #expect(titles("", filter: SearchFilter(favorites: true)) == ["L'Assassin royal"])
    }

    @Test func filtersCombineAndCountWhatTheyHide() {
        let results = LibrarySearchMatcher.results(
            for: "carl", in: library, filter: SearchFilter(favorites: false, status: .reading)
        )
        #expect(results.books.map(\.title) == ["The Butcher's Masquerade"])
        // "carl" is also one letter off "Card", which the filter hides too.
        #expect(results.hiddenByFilter == 3)
    }

    @Test func findsTheSagaWithTheVolumesHeld() {
        let results = LibrarySearchMatcher.results(for: "dungeon crawler", in: library, filter: SearchFilter())
        #expect(results.series.map(\.name) == ["Dungeon Crawler Carl"])
        #expect(results.series.first?.books.map(\.id) == ["dcc1", "dcc2", "dcc5"])
    }

    @Test func showsAtMostThreeSagas() {
        let sagas = (0..<5).map { index in
            var book = Book(id: "s\(index)", title: "Tome", authors: ["Same"], status: .read)
            book.series = SeriesMembership(id: "saga\(index)", name: "Saga \(index)", volume: 1, kind: .main)
            return SearchEntry(book: book)
        }
        #expect(LibrarySearchMatcher.results(for: "saga", in: sagas, filter: SearchFilter()).series.count == 3)
    }

    @Test func highlightsTheTitleWordsThatMatched() {
        #expect(LibrarySearchMatcher.highlights("Carl's", for: "card"))
        #expect(!LibrarySearchMatcher.highlights("Doomsday", for: "card"))
    }

    @Test func searchesFiveThousandBooksWithinBudget() {
        let large = (0..<5_000).map { index in
            var book = Book(id: "b\(index)", title: "Le livre numéro \(index) des archives", authors: ["Auteur \(index % 300)"], status: .read)
            book.series = SeriesMembership(id: "s\(index % 400)", name: "Cycle \(index % 400)", volume: index % 12, kind: .main)
            return SearchEntry(book: book)
        }
        let clock = ContinuousClock()
        let elapsed = clock.measure {
            _ = LibrarySearchMatcher.results(for: "archivs cycle", in: large, filter: SearchFilter())
        }
        // Well under 10 ms on a phone; the ceiling is loose because CI runs
        // the suites in parallel on a slow virtual machine (151 ms seen there),
        // and still far below what a quadratic slip over 5,000 books costs.
        #expect(elapsed < .seconds(1))
    }
}
