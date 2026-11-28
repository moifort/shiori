import Foundation
import Testing
@testable import Shiori

/// The saga of a book the reader does not hold, as its page draws it: read
/// from the saga the server names on the release, this book in its place.
@MainActor
struct ReleaseSagaTests {
    private let edition = Book(
        id: "awaited-sun-eater-4",
        title: "Kingdoms of Death",
        authors: ["Christopher Ruocchio"],
        format: .audiobook,
        series: SeriesMembership(
            id: "sun-eater--christopher-ruocchio--audio~fr", name: "The Sun Eater", volume: 4, kind: .main
        ),
        status: .toRead
    )

    private func lacking(_ number: Int) -> SeriesStripItem {
        .missing(key: "v\(number)", number: number, title: "Tome \(number)", forthcoming: false)
    }

    @Test func theBookTakesItsPlaceInTheRow() {
        let row = ReleaseSaga.row([lacking(1), lacking(2), lacking(3), lacking(4), lacking(5)], placing: edition)

        #expect(row.volumes.map(\.id) == ["missing-v1", "missing-v2", "missing-v3", edition.id, "missing-v5"])
        #expect(row.currentId == edition.id)
    }

    @Test func aVolumeTheCatalogueDoesNotListYetStillHasItsPlace() {
        let row = ReleaseSaga.row([lacking(1), lacking(2), lacking(7)], placing: edition)

        #expect(row.volumes.map(\.id) == ["missing-v1", "missing-v2", edition.id, "missing-v7"])
    }

    @Test func aSagaNobodyCataloguedDrawsTheBookAlone() {
        let row = ReleaseSaga.row([], placing: edition)

        #expect(row.volumes.map(\.id) == [edition.id])
        #expect(row.currentId == edition.id)
    }

    @Test func theReadersOwnCopyOfThatVolumeIsRinged() {
        var held = Book(id: "my-copy", title: edition.title, authors: edition.authors, status: .read)
        held.series = edition.series
        let row = ReleaseSaga.row([lacking(3), .owned(held), lacking(5)], placing: edition)

        #expect(row.volumes.map(\.id) == ["missing-v3", "my-copy", "missing-v5"])
        #expect(row.currentId == "my-copy")
    }

    @Test func withNoCopyTheSagaIsTheOneNamedOnTheRelease() async {
        let asked = AskedSaga()
        let saga = ReleaseSaga { id, language in
            await asked.record(id, language)
            return []
        }

        await saga.load(shown: edition)

        #expect(await asked.calls == ["sun-eater--christopher-ruocchio--audio~fr fr"])
        #expect(saga.series?.id == "sun-eater--christopher-ruocchio--audio~fr")
        #expect(saga.destination?.proposal == SeriesProposal(name: "The Sun Eater", author: "Christopher Ruocchio"))
        #expect(saga.discovery?.series.language == .fr)
        #expect(saga.discovery?.series.ownedCount == 0)
    }

    @Test func theReadersCopyLeadsWhenThePageHasOne() async {
        var copy = Book(id: "copy", title: edition.title, authors: edition.authors, status: .read)
        copy.language = .en
        copy.series = SeriesMembership(id: "sun-eater--christopher-ruocchio~en", name: "The Sun Eater", volume: 4, kind: .main)
        let held = copy
        let saga = ReleaseSaga { _, _ in [.owned(held)] }

        await saga.load(shown: edition, copy: copy)

        #expect(saga.series?.id == "sun-eater--christopher-ruocchio~en")
        #expect(saga.currentId == "copy")
        #expect(saga.discovery?.series.ownedCount == 1)
    }
}

private actor AskedSaga {
    var calls: [String] = []
    func record(_ id: String, _ language: BookLanguage?) {
        calls.append("\(id) \(language?.rawValue ?? "-")")
    }
}
