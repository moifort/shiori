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
            calls.record("rate \(stars.starsText)")
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

    @Test func seriesAddsTheVolumesOutThatAreLacking() async throws {
        let calls = Calls()
        var client = ScanClient.preview
        client.add = { draft in
            calls.record("add \(draft.title) #\(draft.series?.volume ?? 0) \(draft.language?.rawValue ?? "-")")
            return .preview
        }
        client.sagaVolumes = { _, _ in
            [
                .missing(key: "1", number: 1, title: "Tome 1", forthcoming: false),
                .missing(key: "3", number: 3, title: "Tome 3", forthcoming: false),
                .missing(key: "2", number: 2, title: "Tome 2", forthcoming: false),
                .missing(key: "4", number: 4, title: "Tome 4", forthcoming: true),
            ]
        }
        client.scan = { _ in
            ScannedBook(
                recognized: true, title: "Tome 2", authors: ["A"],
                series: SeriesMembership(id: "s", name: "Saga", volume: 2, kind: .main)
            )
        }
        let viewModel = ScanViewModel(client: client)
        await viewModel.capture(Data([1]))
        await viewModel.loadSagaVolumes(language: .fr)
        var draft = try #require(viewModel.draft)
        draft.language = .fr

        let book = await viewModel.saveSeries(draft)

        #expect(book != nil)
        #expect(calls.all == ["add Tome 2 #2 fr", "add Tome 1 #1 fr", "add Tome 3 #3 fr"])
    }

    @Test func aSagaAlreadyInTheLibraryIsNotCompletedFromTheScan() {
        let row: [SeriesStripItem] = [
            .owned(Book(id: "t1", title: "Tome 1", authors: [], series: SeriesMembership(id: "s", name: "Saga", volume: 1, kind: .main), status: .read)),
            .missing(key: "2", number: 2, title: "Tome 2", forthcoming: false),
        ]

        #expect(row.volumesToComplete(besides: 3).isEmpty)
    }

    @Test func aFailedVolumeIsSaidAndTheOthersGoOn() async throws {
        let calls = Calls()
        var client = ScanClient.preview
        client.add = { draft in
            calls.record(draft.title)
            if draft.title == "Tome 2" { throw Boom() }
            return .preview
        }
        client.sagaVolumes = { _, _ in
            [
                .missing(key: "2", number: 2, title: "Tome 2", forthcoming: false),
                .missing(key: "3", number: 3, title: "Tome 3", forthcoming: false),
            ]
        }
        client.scan = { _ in
            ScannedBook(
                recognized: true, title: "Tome 1", authors: ["A"],
                series: SeriesMembership(id: "s", name: "Saga", volume: 1, kind: .main)
            )
        }
        let viewModel = ScanViewModel(client: client)
        await viewModel.capture(Data([1]))
        await viewModel.loadSagaVolumes(language: nil)
        let draft = try #require(viewModel.draft)

        let book = await viewModel.saveSeries(draft)

        #expect(book != nil)
        #expect(calls.all == ["Tome 1", "Tome 2", "Tome 3"])
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
