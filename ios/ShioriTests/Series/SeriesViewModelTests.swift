import Foundation
import Testing
@testable import Shiori

@MainActor
struct SeriesViewModelTests {
    private static var sagaId: String { SeriesFixtures.followed[0].seriesId }

    private func model(_ client: SeriesClient = .preview, friend: SeriesFriend? = nil) -> SeriesViewModel {
        SeriesViewModel(seriesId: Self.sagaId, proposal: nil, friend: friend, client: client)
    }

    @Test func loadDrawsTheCatalogueAndTheVolumesHeld() async {
        let viewModel = model()

        await viewModel.load()

        #expect(viewModel.series?.id == Self.sagaId)
        #expect(viewModel.owned.map(\.id) == SeriesFixtures.screen.owned.map(\.id))
        #expect(viewModel.isLoading == false)
    }

    @Test func sagaAwaitingItsCatalogueIsBuiltWhileTheVolumesShow() async {
        let full = SeriesFixtures.screen
        var awaiting = full.series
        awaiting?.isAwaitingCatalogue = true
        let asked = Calls()
        var client = SeriesClient.preview
        client.screen = { [awaiting] _, _ in (awaiting, full.opinion, full.owned) }
        client.catalogue = { _, _ in
            asked.record("catalogue")
            return full.series
        }
        let viewModel = model(client)
        await viewModel.load()
        #expect(viewModel.series?.isAwaitingCatalogue == true)

        await viewModel.buildCatalogueIfAwaiting()

        #expect(asked.all == ["catalogue"])
        #expect(viewModel.series?.isAwaitingCatalogue == false)
        #expect(!viewModel.isGenerating)
    }

    @Test func storedCatalogueIsNotBuiltAgain() async {
        let asked = Calls()
        var client = SeriesClient.preview
        client.catalogue = { _, _ in
            asked.record("catalogue")
            return nil
        }
        let viewModel = model(client)
        await viewModel.load()

        await viewModel.buildCatalogueIfAwaiting()

        #expect(asked.all.isEmpty)
    }

    @Test func friendsShelfAsksTheirSaga() async {
        let asked = Calls()
        var client = SeriesClient.preview
        client.friendScreen = { friendId, seriesId in
            asked.record(friendId)
            return (Showcase.seriesScreen(id: seriesId).series, nil)
        }
        client.screen = { _, _ in
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
            calls.record("rate \(stars.starsText)")
            return SeriesOpinion(seriesId: id, rating: stars)
        }
        let viewModel = model(client)

        await viewModel.rate(4)
        await viewModel.rate(0)

        #expect(calls.all == ["rate 4", "remove"])
        #expect(viewModel.opinion?.rating == nil)
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

        // Filed in the edition the screen loaded, whatever the device speaks.
        let edition = try! #require(viewModel.language)
        #expect(asked.all == ["\(Self.sagaId) \(edition.rawValue) looked up"])
        #expect(viewModel.owned.count == before + 1)
        #expect(viewModel.addingTitle == nil)
    }

    @Test func recordingAudibleDoesNotSellIsAddedAsABook() async {
        let asked = Calls()
        var client = SeriesClient.preview
        client.addAudibleVolume = { _, _ in throw APIError.domain(code: "NOT_FOUND", messages: []) }
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
        client.delete = { _ in throw Boom() }
        let viewModel = model(client)

        let removed = await viewModel.delete()

        #expect(removed == false)
        #expect(viewModel.errorMessage != nil)
    }

    @Test func bellTurnsAtOnceWithoutAScrim() async {
        let (started, calling) = AsyncStream<Void>.makeStream()
        let (answer, answering) = AsyncStream<Void>.makeStream()
        var client = SeriesClient.preview
        client.setFollowed = { seriesId, followed in
            calling.yield()
            for await _ in answer { break }
            return SeriesOpinion(seriesId: seriesId, followed: followed)
        }
        let viewModel = model(client)
        await viewModel.load()
        #expect(viewModel.isFollowed)

        let tap = Task { await viewModel.setFollowed(false) }
        for await _ in started { break }

        #expect(viewModel.isFollowed == false)
        #expect(viewModel.isSaving == false)
        answering.yield()
        await tap.value
        #expect(viewModel.isFollowed == false)
    }

    @Test func refusedBellTurnsBack() async {
        var client = SeriesClient.preview
        client.setFollowed = { _, _ in throw Boom() }
        let viewModel = model(client)
        await viewModel.load()

        await viewModel.setFollowed(false)

        #expect(viewModel.isFollowed)
        #expect(viewModel.errorMessage != nil)
    }

    @Test func correctionReadsTheVolumesAgain() async {
        let calls = Calls()
        var client = SeriesClient.preview
        let screen = client.screen
        client.screen = { id, proposal in
            calls.record("screen")
            return try await screen(id, proposal)
        }
        client.correct = { _, correction in
            calls.record("correct \(correction.format?.rawValue ?? "-")")
            return SeriesFixtures.screen.series
        }
        let viewModel = model(client)
        await viewModel.load()

        let failure = await viewModel.correct(SeriesCorrection(format: .manga))

        #expect(failure == nil)
        #expect(calls.all == ["screen", "correct manga", "screen"])
    }
}
