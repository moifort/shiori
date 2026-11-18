import Foundation
import Testing
@testable import Shiori

/// A volume the reader lacks, opened from the saga row of a book they hold:
/// its page reads the saga in the edition of their copy.
struct LackingVolumeTests {
    private let copy = Book(
        id: "chaman-5",
        title: "L'Échiquier de Karmadont",
        authors: ["Vasily Mahanenko"],
        format: .audiobook,
        language: .fr,
        series: SeriesMembership(id: "chaman~fr", name: "La voie du Chaman", volume: 5, kind: .main),
        status: .toRead
    )

    @Test func theSagaIsTheEditionOfTheReadersCopy() throws {
        let series = try #require(copy.series)

        let saga = SagaDiscovery(holding: copy, in: series, ownedCount: 3)

        #expect(saga.series.seriesId == "chaman~fr")
        #expect(saga.series.name == "La voie du Chaman")
        #expect(saga.series.isAudio)
        #expect(saga.series.author == "Vasily Mahanenko")
        #expect(saga.series.language == .fr)
        #expect(saga.series.ownedCount == 3)
    }

    @Test func theVolumeIsFiledAtItsNumberInTheSaga() throws {
        let series = try #require(copy.series)
        let saga = SagaDiscovery(holding: copy, in: series, ownedCount: 3)
        let lacking = DiscoveredVolume(number: 4, title: "Le Château spectral", date: nil, isbn13: nil, coverURL: nil)

        let opened = DiscoveryVolume(saga: saga, volume: lacking)

        #expect(opened.volume.number == 4)
        #expect(opened.volume.release.series?.id == "chaman~fr")
        #expect(opened.volume.release.series?.volume == 4)
        #expect(opened.volume.release.authors == ["Vasily Mahanenko"])
        #expect(opened.volume.release.format == .audiobook)
    }
}
