import Foundation
import Testing
@testable import Shiori

@Suite("Positions kept on the iPhone")
struct ListeningPositionsTests {
    private let earlier = Date(timeIntervalSince1970: 1_000)
    private let later = Date(timeIntervalSince1970: 2_000)

    private func store() -> ListeningPositions {
        let defaults = UserDefaults(suiteName: "positions-\(UUID().uuidString)")!
        return ListeningPositions(defaults: defaults)
    }

    @Test("a position saved offline waits until it is sent")
    func pendingUntilSent() {
        let positions = store()
        positions.record("B1", at: 120, contentReference: "CR!1", now: earlier)
        #expect(positions.pending().keys.sorted() == ["B1"])

        positions.markSent("B1", savedAt: earlier)
        #expect(positions.pending().isEmpty)
        #expect(positions.entry("B1")?.position == 120)
    }

    @Test("a later save is not marked sent by an earlier one's answer")
    func laterSaveStaysPending() {
        let positions = store()
        positions.record("B1", at: 120, contentReference: "CR!1", now: earlier)
        positions.record("B1", at: 180, contentReference: "CR!1", now: later)

        positions.markSent("B1", savedAt: earlier)
        #expect(positions.pending()["B1"]?.position == 180)
    }

    @Test("resumes from whichever of Audible and the iPhone saved last")
    func resumeFromLatest() {
        let local = ListeningPositions.Entry(position: 300, contentReference: "CR!1", savedAt: later, isPending: true)
        #expect(ListeningPositions.resume(audible: 100, savedAt: earlier, local: local) == 300)

        let stale = ListeningPositions.Entry(position: 50, contentReference: "CR!1", savedAt: earlier, isPending: false)
        #expect(ListeningPositions.resume(audible: 100, savedAt: later, local: stale) == 100)

        #expect(ListeningPositions.resume(audible: nil, savedAt: nil, local: stale) == 50)
        #expect(ListeningPositions.resume(audible: 100, savedAt: nil, local: nil) == 100)
    }
}

@Suite("The title listened to last")
struct LastListenedTitleTests {
    private func store() -> LastListenedTitle {
        LastListenedTitle(defaults: UserDefaults(suiteName: "last-title-\(UUID().uuidString)")!)
    }

    @Test("the title kept is found again, cover and book included")
    func keptAndFound() {
        let last = store()
        #expect(last.value == nil)
        let title = ListeningTitle(
            asin: "B077PLB5KD",
            title: "Endymion",
            subtitle: "Les Cantos d'Hypérion · Tome 3",
            coverURL: URL(string: "https://example.com/cover.jpg"),
            bookID: "book-1"
        )
        last.value = title
        #expect(last.value == title)
    }

    @Test("stopping forgets it")
    func forgotten() {
        let last = store()
        last.value = ListeningTitle(asin: "B1", title: "Seul sur Mars", subtitle: nil, coverURL: nil)
        last.value = nil
        #expect(last.value == nil)
    }
}
