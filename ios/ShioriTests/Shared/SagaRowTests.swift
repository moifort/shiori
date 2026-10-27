import Foundation
import Testing
@testable import Shiori

/// The row of a saga's volumes under a book's facts.
struct SagaRowTests {
    private func book(_ id: String, volume: Int?, kind: VolumeKind = .main) -> Book {
        Book(
            id: id,
            title: "Le chuchoteur",
            authors: ["Donato Carrisi"],
            series: SeriesMembership(id: "chuchoteur", name: "Le chuchoteur", volume: volume, kind: kind),
            status: .read
        )
    }

    private func spine(_ numbers: ClosedRange<Int>) -> [Volume] {
        numbers.map { Volume(number: $0, title: "Tome \($0)", publishedIn: 2010, kind: .main) }
    }

    @Test func theVolumesLackedSitBetweenTheOnesHeld() {
        let row = SeriesStripItem.sagaRow(
            owned: [book("one", volume: 1), book("three", volume: 3)],
            spine: spine(1...4),
            currentYear: 2026
        )

        #expect(row.map(\.id) == ["one", "missing-main-2", "three", "missing-main-4"])
    }

    @Test func withoutACatalogueOnlyTheVolumesHeldShow() {
        let row = SeriesStripItem.sagaRow(
            owned: [book("one", volume: 1), book("two", volume: 2)],
            spine: [],
            currentYear: 2026
        )

        #expect(row.map(\.id) == ["one", "two"])
    }

    @Test func aBookHeldOffTheSpineStaysInItsOwnRow() {
        let row = SeriesStripItem.sagaRow(
            owned: [book("one", volume: 1), book("prequel", volume: nil, kind: .prequel)],
            spine: spine(1...2),
            currentYear: 2026
        )

        #expect(row.map(\.id) == ["one", "missing-main-2", "prequel"])
    }

    @Test func aBookFiledWithoutANumberTakesTheVolumeOfItsTitle() {
        let filed = { (id: String, title: String) in
            Book(
                id: id,
                title: title,
                authors: ["Yuval Noah Harari"],
                series: SeriesMembership(id: "sapiens", name: "Sapiens", volume: nil, kind: .main),
                status: .read
            )
        }
        let row = SeriesStripItem.sagaRow(
            owned: [filed("homo", "Homo deus"), filed("sapiens", "Sapiens"), filed("lessons", "21 leçons")],
            spine: [
                Volume(number: 1, title: "Sapiens : Une brève histoire de l'humanité", publishedIn: 2011, kind: .main),
                Volume(number: 2, title: "Homo deus : Une brève histoire du futur", publishedIn: 2015, kind: .main),
                Volume(number: 3, title: "Homo dei", publishedIn: 2030, kind: .main),
            ],
            currentYear: 2026
        )

        #expect(row.map(\.id) == ["sapiens", "homo", "missing-main-3", "lessons"])
    }

    @Test func aCatalogueTitlingEveryVolumeAfterTheSagaPlacesNoneByTitle() {
        let unnumbered = Book(
            id: "op",
            title: "One Piece",
            authors: ["Eiichiro Oda"],
            series: SeriesMembership(id: "op", name: "One Piece", volume: nil, kind: .main),
            status: .read
        )
        let row = SeriesStripItem.sagaRow(
            owned: [unnumbered],
            spine: (1...2).map { Volume(number: $0, title: "One Piece", publishedIn: 1997, kind: .main) },
            currentYear: 2026
        )

        #expect(row.map(\.id) == ["missing-main-1", "missing-main-2", "op"])
    }
}
