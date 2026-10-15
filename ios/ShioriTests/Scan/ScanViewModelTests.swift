import Foundation
import Testing
@testable import Shiori

@MainActor
struct ScanViewModelTests {
    @Test func recognisedCoverGoesToReview() async {
        let viewModel = ScanViewModel(client: .preview)

        await viewModel.capture(Data([1]))

        #expect(viewModel.step == .review)
        #expect(viewModel.draft?.title == "Dune")
    }

    @Test func unreadCoverSaysNoResult() async {
        var client = ScanClient.preview
        client.scan = { _ in ScannedBook(recognized: false) }
        let viewModel = ScanViewModel(client: client)

        await viewModel.capture(Data([1]))

        #expect(viewModel.step == .noResult)
    }

    @Test func spentAllowanceOpensThePaywall() async {
        var client = ScanClient.preview
        client.scan = { _ in throw APIError.domain(code: "QUOTA_EXHAUSTED", messages: []) }
        let viewModel = ScanViewModel(client: client)

        await viewModel.capture(Data([1]))

        #expect(viewModel.paywallShown)
        #expect(viewModel.step == .camera)
    }

    @Test func failedAnalysisKeepsTheShotForARetry() async {
        let fails = Flag()
        fails.isOn = true
        var client = ScanClient.preview
        client.scan = { _ in
            if fails.isOn { throw Boom() }
            return .preview
        }
        let viewModel = ScanViewModel(client: client)
        await viewModel.capture(Data([1]))
        #expect(viewModel.step == .failed)

        fails.isOn = false
        await viewModel.retry()

        #expect(viewModel.step == .review)
    }

    @Test func saveFilesARenamedSagaThenRatesThenHearts() async {
        let calls = Calls()
        var client = ScanClient.preview
        client.add = { draft in
            calls.record("add series=\(draft.series?.name ?? "none")")
            return .preview
        }
        client.update = { _, _ in
            calls.record("file")
            return .preview
        }
        client.rate = { _, stars in
            calls.record("rate \(stars)")
            return .preview
        }
        client.setFavorite = { _, _ in
            calls.record("heart")
            return .preview
        }
        let viewModel = ScanViewModel(client: client)
        var draft = ScannedBook.preview.asDraft
        draft.series = SeriesMembership(id: "dune", name: "Dune", volume: 1, kind: .main)
        draft.rating = 5
        draft.favorite = true

        let book = await viewModel.save(draft, series: SeriesPlacement(name: "Le cycle de Dune", volume: 1))

        #expect(book != nil)
        #expect(calls.all == ["add series=none", "file", "rate 5", "heart"])
    }

    @Test func refusedAddSaysSo() async {
        var client = ScanClient.preview
        client.add = { _ in throw Boom() }
        let viewModel = ScanViewModel(client: client)

        let book = await viewModel.save(ScannedBook.preview.asDraft)

        #expect(book == nil)
        #expect(viewModel.error != nil)
    }

    @Test func nothingToAwaitWithoutALanguage() async {
        let viewModel = ScanViewModel(client: .preview)

        await viewModel.loadAwaitable(language: nil, format: .book)
        #expect(viewModel.awaitable.isEmpty)

        await viewModel.loadAwaitable(language: .en, format: .book)
        #expect(viewModel.awaitable == [.audiobook])
    }
}

@MainActor
struct ShelfImportViewModelTests {
    @Test func detectionTicksWhatCanBeAdded() async {
        let viewModel = ShelfImportViewModel(client: .preview)

        await viewModel.detect(Data([1]))

        #expect(viewModel.step == .checklist)
        // Fondation is owned and the fourth spine unread: both left unticked.
        #expect(viewModel.ticked == [0, 1, 4])
        #expect(viewModel.remainingScans == 94)
    }

    @Test func nothingFoundSaysNoResult() async {
        var client = ScanClient.preview
        client.detectShelf = { _ in [] }
        let viewModel = ShelfImportViewModel(client: client)

        await viewModel.detect(Data([1]))

        #expect(viewModel.step == .noResult)
    }

    @Test func premiumOnlyOpensThePaywall() async {
        var client = ScanClient.preview
        client.detectShelf = { _ in throw APIError.domain(code: "PREMIUM_REQUIRED", messages: []) }
        let viewModel = ShelfImportViewModel(client: client)

        await viewModel.detect(Data([1]))

        #expect(viewModel.paywallShown)
    }

    @Test func moreTickedThanScansLeftIsSaid() async {
        var client = ScanClient.preview
        client.remainingScans = { 2 }
        let viewModel = ShelfImportViewModel(client: client)

        await viewModel.detect(Data([1]))

        #expect(viewModel.exceedsAllowance)
    }
}
