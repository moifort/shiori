import Foundation
import Testing
@testable import Shiori

@MainActor
struct SeriesViewModelTests {
    private static var sagaId: String { SeriesFixtures.followed[0].seriesId }

    private func model(_ client: SeriesClient = .preview, friend: SeriesFriend? = nil) -> SeriesViewModel {
        SeriesViewModel(seriesId: Self.sagaId, language: .fr, proposal: nil, friend: friend, client: client)
    }

    @Test func loadDrawsTheCatalogueAndTheVolumesHeld() async {
        let viewModel = model()

        await viewModel.load()

        #expect(viewModel.series?.id == Self.sagaId)
        #expect(viewModel.owned.map(\.id) == SeriesFixtures.screen.owned.map(\.id))
        #expect(viewModel.isLoading == false)
    }

    @Test func friendsShelfAsksTheirSaga() async {
        let asked = Calls()
        var client = SeriesClient.preview
        client.friendScreen = { friendId, seriesId, _ in
            asked.record(friendId)
            return (Showcase.seriesScreen(id: seriesId).series, nil)
        }
        client.screen = { _, _, _ in
            asked.record("own")
            return (nil, nil, [])
        }
        let viewModel = model(client, friend: SeriesFriend(id: "camille", name: "Camille"))

        await viewModel.load()

        #expect(asked.all == ["camille"])
        #expect(viewModel.series != nil)
    }

    @Test func zeroStarsTakesTheRatingBack() async {
        let calls = Calls()
        var client = SeriesClient.preview
        client.removeRating = { id in
            calls.record("remove")
            return SeriesOpinion(seriesId: id)
        }
        client.rate = { id, stars in
            calls.record("rate \(stars)")
            return SeriesOpinion(seriesId: id, rating: stars)
        }
        let viewModel = model(client)

        await viewModel.rate(4)
        await viewModel.rate(0)

        #expect(calls.all == ["rate 4", "remove"])
        #expect(viewModel.opinion?.rating == nil)
    }

    @Test func emptyRefreshKeepsTheOldCatalogueAndSaysSo() async {
        var client = SeriesClient.preview
        client.refresh = { _, _ in nil }
        let viewModel = model(client)
        await viewModel.load()

        await viewModel.refreshCatalogue()

        #expect(viewModel.series != nil)
        #expect(viewModel.refreshFailed)
        #expect(viewModel.isSaving == false)
    }

    @Test func genreCorrectionReachesEveryVolume() async {
        var client = SeriesClient.preview
        client.updateBook = { _, _ in
            var book = Book.preview
            book.genre = .horror
            return book
        }
        let viewModel = model(client)
        await viewModel.load()
        var correction = BookCorrection()
        correction.genre = .set(.horror)

        let failure = await viewModel.correctGenre(correction)

        #expect(failure == nil)
        #expect(viewModel.owned.allSatisfy { $0.genre == .horror })
    }

    @Test func volumeAddedIsLookedUpAndFiledInTheEdition() async {
        let asked = Calls()
        var client = SeriesClient.preview
        client.addBook = { draft, lookUp in
            asked.record("\(draft.series?.id ?? "none") \(draft.language?.rawValue ?? "none") \(lookUp == nil ? "bare" : "looked up")")
            return .preview
        }
        let viewModel = model(client)
        await viewModel.load()
        let before = viewModel.owned.count
        let volume = try! #require(viewModel.series?.spine.first)

        await viewModel.add(volume, author: "Auteur", as: .book)

        #expect(asked.all == ["\(Self.sagaId) fr looked up"])
        #expect(viewModel.owned.count == before + 1)
        #expect(viewModel.addingTitle == nil)
    }

    @Test func recordingAudibleDoesNotSellIsAddedAsABook() async {
        let asked = Calls()
        var client = SeriesClient.preview
        client.addAudibleVolume = { _, _, _ in throw APIError.domain(code: "NOT_FOUND", messages: []) }
        client.addBook = { draft, _ in
            asked.record(draft.format.rawValue)
            return .preview
        }
        let viewModel = model(client)
        await viewModel.load()
        let volume = try! #require(viewModel.series?.spine.first { $0.kind == .main && $0.number != nil })

        await viewModel.add(volume, author: "Auteur", as: .audiobook)

        #expect(asked.all == ["audiobook"])
        #expect(viewModel.errorMessage == nil)
    }

    @Test func refusedRemovalStays() async {
        var client = SeriesClient.preview
        client.delete = { _, _ in throw Boom() }
        let viewModel = model(client)

        let removed = await viewModel.delete()

        #expect(removed == false)
        #expect(viewModel.errorMessage != nil)
    }
}

@MainActor
struct SeriesListViewModelTests {
    @Test func loadShowsTheFirstPage() async {
        let viewModel = SeriesListViewModel(client: .preview, caching: false)

        await viewModel.load()

        let firstPage = Showcase.seriesPage(limit: 40, after: nil, mode: .all, state: nil).items
        #expect(viewModel.followed.map(\.id) == firstPage.map(\.id))
        #expect(viewModel.isLoading == false)
    }

    @Test func failureOverRowsKeepsThem() async {
        let fails = Flag()
        var client = SeriesClient.preview
        client.page = { limit, after, mode, state in
            if fails.isOn { throw Boom() }
            return Showcase.seriesPage(limit: limit, after: after, mode: mode, state: state)
        }
        let viewModel = SeriesListViewModel(client: client, caching: false)
        await viewModel.load()
        let shown = viewModel.followed.map(\.id)

        fails.isOn = true
        await viewModel.load()

        #expect(viewModel.followed.map(\.id) == shown)
    }

    @Test func cappedPagesFollowOneAnother() async {
        let cursors = Calls()
        var client = SeriesClient.preview
        client.page = { limit, after, mode, state in
            cursors.record(after ?? "top")
            return Showcase.seriesPage(limit: min(limit, 2), after: after, mode: mode, state: state)
        }
        let viewModel = SeriesListViewModel(client: client, caching: false)

        await viewModel.load()

        // Each page starts after the last row of the one before.
        let ids = viewModel.followed.map(\.id)
        #expect(ids.count > 2)
        #expect(cursors.all == ["top"] + stride(from: 1, to: ids.count - 1, by: 2).map { ids[$0] })
    }
}
