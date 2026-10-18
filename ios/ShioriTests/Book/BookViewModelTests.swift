import Foundation
import Testing
@testable import Shiori

@MainActor
struct BookViewModelTests {
    @Test func loadShowsTheBook() async {
        let viewModel = BookViewModel(bookId: "preview", client: .preview)

        await viewModel.load()

        #expect(viewModel.book?.id == Book.preview.id)
        #expect(viewModel.isLoading == false)
    }

    @Test func missingBookSaysSo() async {
        var client = BookClient.preview
        client.book = { _ in throw Boom() }
        let viewModel = BookViewModel(bookId: "preview", client: client)

        await viewModel.load()

        #expect(viewModel.book == nil)
        #expect(viewModel.errorMessage != nil)
    }

    @Test func shelfBookIsDescribedOnFirstOpening() async {
        var client = BookClient.preview
        client.book = { _ in .previewFromShelf }
        client.describe = { _ in
            var book = Book.previewFromShelf
            book.synopsis = "Luffy prend la mer."
            book.awaitingDescription = false
            return book
        }
        let viewModel = BookViewModel(bookId: "2", client: client)
        await viewModel.load()

        let changed = await viewModel.describeIfAwaiting()

        #expect(changed)
        #expect(viewModel.book?.synopsis == "Luffy prend la mer.")
        #expect(viewModel.isDescribing == false)
    }

    @Test func describedBookIsNotAskedAgain() async {
        var client = BookClient.preview
        client.describe = { _ in throw Boom() }
        let viewModel = BookViewModel(bookId: "preview", client: client)
        await viewModel.load()

        #expect(await viewModel.describeIfAwaiting() == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func failedDescriptionKeepsTheSpineSilently() async {
        var client = BookClient.preview
        client.book = { _ in .previewFromShelf }
        client.describe = { _ in throw Boom() }
        let viewModel = BookViewModel(bookId: "2", client: client)
        await viewModel.load()

        #expect(await viewModel.describeIfAwaiting() == false)
        #expect(viewModel.book?.awaitingDescription == true)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func mutationTakesTheServersRecord() async {
        let viewModel = BookViewModel(bookId: "preview", client: .preview)
        await viewModel.load()

        await viewModel.rate(5)

        #expect(viewModel.book?.rating == 5)
        #expect(viewModel.isSaving == false)
    }

    @Test func refusedMutationKeepsTheBook() async {
        var client = BookClient.preview
        client.setFavorite = { _, _ in throw Boom() }
        let viewModel = BookViewModel(bookId: "preview", client: client)
        await viewModel.load()
        let before = viewModel.book?.favorite

        await viewModel.setFavorite(!(before ?? false))

        #expect(viewModel.book?.favorite == before)
        #expect(viewModel.errorMessage != nil)
    }

    @Test func saveSendsTheRatingOnlyWhenItMoved() async {
        let ratings = Calls()
        var client = BookClient.preview
        client.save = { _, _, rating in
            ratings.record(rating.map { "\($0.map(String.init) ?? "nil")" } ?? "unchanged")
            return .preview
        }
        let viewModel = BookViewModel(bookId: "preview", client: client)
        await viewModel.load()
        let current = viewModel.book?.rating

        _ = await viewModel.save(BookCorrection(), rating: current)
        _ = await viewModel.save(BookCorrection(), rating: 1)

        #expect(ratings.all == ["unchanged", "1"])
    }

    @Test func refusedSaveKeepsTheFormOpen() async {
        var client = BookClient.preview
        client.save = { _, _, _ in throw Boom() }
        let viewModel = BookViewModel(bookId: "preview", client: client)
        await viewModel.load()

        let saved = await viewModel.save(BookCorrection(), rating: nil)

        #expect(saved == false)
        #expect(viewModel.errorMessage != nil)
    }

    @Test func exhaustedQuotaIsSaidInTheReadersWords() async {
        var client = BookClient.preview
        client.refresh = { _ in throw APIError.domain(code: "QUOTA_EXHAUSTED", messages: []) }
        let viewModel = BookViewModel(bookId: "preview", client: client)
        await viewModel.load()

        await viewModel.refresh()

        #expect(viewModel.errorMessage?.contains("scans") == true)
        #expect(viewModel.isRefreshing == false)
    }

    @Test func awaitedEditionShowsAtOnceAndCanBeGivenUp() async {
        let viewModel = BookViewModel(bookId: "preview", client: .preview)
        await viewModel.load()

        viewModel.awaitEdition(.audiobook)
        #expect(viewModel.offer.awaited.map(\.format) == [.audiobook])

        await viewModel.stopAwaiting(viewModel.offer.awaited[0])
        #expect(viewModel.offer.awaited.isEmpty)
    }

    @Test func refusedAwaitIsTakenBackAndSaid() async {
        var client = BookClient.preview
        client.awaitEdition = { _, _ in throw Boom() }
        let viewModel = BookViewModel(bookId: "preview", client: client)
        await viewModel.load()

        viewModel.awaitEdition(.book)
        // Giving it up waits for the answer, which is a refusal.
        await viewModel.stopAwaiting(viewModel.offer.awaited[0])

        #expect(viewModel.offer.awaited.isEmpty)
        #expect(viewModel.awaitFailed != nil)
    }
}
