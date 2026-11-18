import Foundation
import Testing
@testable import Shiori

@Suite("Where the listener stands")
struct ListeningProgressTests {
    private let chapters = [
        ListeningChapter(title: "Ouverture", start: 0, length: 60),
        ListeningChapter(title: "Chapitre 1", start: 60, length: 600),
        ListeningChapter(title: "Chapitre 2", start: 660, length: 340),
    ]

    private func at(_ elapsed: TimeInterval) -> ListeningProgress {
        ListeningProgress(elapsed: elapsed, duration: 1000, chapters: chapters)
    }

    @Test("names the chapter by its place, the time in it and what is left of it")
    func chapterFigures() {
        let progress = at(360)
        #expect(progress.chapterNumber == 2)
        #expect(progress.chapterElapsed == 300)
        #expect(progress.chapterRemaining == 300)
        #expect(progress.chapterFraction == 0.5)
        #expect(progress.remaining == 640)
        #expect(progress.percent == 36)
    }

    @Test("counts a position a hair before a chapter as that chapter")
    func roundingAtBoundary() {
        #expect(at(659.8).chapterNumber == 3)
    }

    @Test("previous goes to the chapter's start, or the one before within its first seconds")
    func previousChapter() {
        #expect(at(400).previousChapterStart == 60)
        #expect(at(62).previousChapterStart == 0)
        #expect(at(1).previousChapterStart == 0)
    }

    @Test("next goes to the following chapter, and nowhere from the last")
    func nextChapter() {
        #expect(at(100).nextChapterStart == 660)
        #expect(at(700).nextChapterStart == nil)
    }

    @Test("without chapters, the bar runs over the whole recording")
    func noChapters() {
        let progress = ListeningProgress(elapsed: 250, duration: 1000, chapters: [])
        #expect(progress.chapterNumber == nil)
        #expect(progress.chapterFraction == 0.25)
        #expect(progress.chapterRemaining == 750)
    }

    @Test("the board's figures: chapter 12 of 40, 18:42 in, 11h47 and 46% left")
    func boardFixture() {
        let progress = ListeningProgress.preview
        #expect(progress.chapterNumber == 12)
        #expect(ListeningText.clock(progress.chapterElapsed) == "18:42")
        #expect(ListeningText.clock(progress.chapterRemaining) == "9:16")
        #expect(progress.percent == 46)
    }
}

@Suite("The player's time phrases")
struct ListeningTextTests {
    @Test("a clock position, with hours only past an hour")
    func clock() {
        #expect(ListeningText.clock(0) == "0:00")
        #expect(ListeningText.clock(1122.9) == "18:42")
        #expect(ListeningText.clock(3725) == "1:02:05")
    }

    @Test("what is left, in hours and minutes, or minutes alone")
    func remaining() {
        #expect(ListeningText.remaining(42420) == String(localized: "\(11)h\("47") restantes"))
        #expect(ListeningText.remaining(2801) == String(localized: "\(47) min restantes"))
    }
}

@Suite("What an audiobook plays")
struct ListeningTitleTests {
    private func book(format: BookFormat, audible: String?) -> Book {
        Book(
            id: "b1",
            title: "Endymion",
            authors: ["Dan Simmons"],
            format: format,
            audibleURL: audible.flatMap(URL.init(string:)),
            status: .toRead
        )
    }

    @Test("an audiobook imported from Audible plays its ASIN")
    func playable() {
        let title = ListeningTitle(book: book(format: .audiobook, audible: "https://www.audible.fr/pd/B077PLB5KD"))
        #expect(title?.asin == "B077PLB5KD")
        #expect(title?.bookID == "b1")
    }

    @Test("a paper book, or an audiobook with no Audible page, plays nothing")
    func notPlayable() {
        #expect(ListeningTitle(book: book(format: .book, audible: "https://www.audible.fr/pd/B077PLB5KD")) == nil)
        #expect(ListeningTitle(book: book(format: .audiobook, audible: nil)) == nil)
        #expect(ListeningTitle(book: book(format: .audiobook, audible: "https://www.audible.fr/pd/")) == nil)
    }
}
