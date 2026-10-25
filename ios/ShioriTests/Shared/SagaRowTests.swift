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
}
