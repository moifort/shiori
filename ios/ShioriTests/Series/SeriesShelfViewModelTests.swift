import Foundation
import Testing
@testable import Shiori

@MainActor
struct SeriesShelfViewModelTests {
    /// A saga followed whose next volume comes out `months` from now.
    private func saga(_ number: Int, inMonths months: Int) -> FollowedSeries {
        let date = Calendar.current.date(byAdding: .month, value: months, to: .now)!
        return FollowedSeries(
            seriesId: "saga-\(number)",
            name: "Saga \(number)",
            author: nil,
            language: nil,
            state: .inProgress,
            genre: nil,
            ownedCount: 1,
            announced: DiscoveredVolume(
                number: 2,
                title: "Saga \(number)",
                date: date.formatted(.iso8601.year().month().day()),
                isbn13: nil,
                coverURL: nil
            )
        )
    }

    @Test func releasesKeepTheNearestFive() async {
        let sagas = (1...8).reversed().map { saga($0, inMonths: $0) }
        var client = SeriesClient.preview
        client.page = { limit, after in CursorPage(sagas, limit: limit, after: after) { $0.seriesId } }
        let viewModel = SeriesShelfViewModel(client: client, caching: false)

        await viewModel.load()

        #expect(viewModel.releases.map(\.series.seriesId) == (1...5).map { "saga-\($0)" })
    }
}
