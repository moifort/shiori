import Foundation
import Testing
@testable import Shiori

@MainActor
struct SuggestionViewModelTests {
    @Test func anAdditionGoesOnTheShelfInTheAppsLanguage() async {
        let calls = Calls()
        var client = DiscoverClient.preview
        client.addBook = { draft in
            calls.record("add \(draft.title) \(draft.status) \(draft.language.map(\.rawValue) ?? "none")")
        }
        let viewModel = SuggestionViewModel(suggestion: .preview, client: client)

        await viewModel.add(status: .read)

        #expect(calls.all == ["add Les Salauds Gentilshommes read none"])
    }

    @Test func aRecordingIsHeldOnNoMedium() {
        var suggestion = Suggestion.preview
        suggestion = Suggestion(
            id: suggestion.id, format: .audiobook, title: suggestion.title,
            originalTitle: suggestion.originalTitle, originalLanguage: suggestion.originalLanguage,
            authors: suggestion.authors, reason: suggestion.reason, short: suggestion.short,
            references: suggestion.references, state: suggestion.state, watched: suggestion.watched,
            date: suggestion.date, coverURL: suggestion.coverURL, storeURL: suggestion.storeURL,
            awaitableFormats: suggestion.awaitableFormats, awaitedEditionId: suggestion.awaitedEditionId
        )
        let viewModel = SuggestionViewModel(suggestion: suggestion, client: .preview)

        let draft = viewModel.draft(status: .toRead)

        #expect(draft.format == .audiobook)
        #expect(draft.media.isEmpty)
    }

    @Test func aWaitIsAskedInTheFormatChosen() async {
        let calls = Calls()
        var client = DiscoverClient.preview
        client.awaitEdition = { draft, format in
            calls.record("await \(draft.title) \(format.rawValue)")
            return .pending(format: format, of: draft)
        }
        let viewModel = SuggestionViewModel(suggestion: .preview, client: client)

        await viewModel.awaitEdition(.audiobook)

        #expect(calls.all == ["await \(Suggestion.preview.draft.title) audiobook"])
    }

    @Test func theDescriptionFillsThePage() async {
        let viewModel = SuggestionViewModel(suggestion: .preview, client: .preview)

        await viewModel.describe()

        #expect(viewModel.shown.synopsis == ReleaseDescription.preview.book.synopsis)
        #expect(viewModel.isDescribing == false)
    }
}

@MainActor
struct ReleaseDescriberTests {
    @Test func aCachedAnswerNeverSaysTheAIIsAtWork() async {
        let seen = Calls()
        let describer = ReleaseDescriber { _ in .preview }
        // Observed as the page would: the flag is sampled when the answer lands.
        await describer.describe(Suggestion.preview.seed)
        seen.record(describer.isDescribing ? "on" : "off")

        #expect(seen.all == ["off"])
        #expect(describer.description != nil)
    }

    @Test func aSlowAnswerSaysTheAIIsAtWorkThenStops() async {
        // The answer waits for the test, so the grace runs out however slow the machine.
        let (answered, answer) = AsyncStream<Void>.makeStream()
        let describer = ReleaseDescriber { _ in
            for await _ in answered { break }
            return .preview
        }
        async let done: Void = describer.describe(Suggestion.preview.seed)
        await eventually { describer.isDescribing }
        let midway = describer.isDescribing
        answer.yield()
        await done

        #expect(midway == true)
        #expect(describer.isDescribing == false)
        #expect(describer.description != nil)
    }
}

@MainActor
struct AwaitedEditionViewModelTests {
    @Test func theDescriptionFillsThePage() async {
        let viewModel = AwaitedEditionViewModel(edition: .preview, client: .preview)

        await viewModel.describe()

        #expect(viewModel.shown.synopsis == ReleaseDescription.preview.book.synopsis)
    }

    @Test func aSpentAllowanceLeavesThePagePlain() async {
        var client = DiscoverClient.preview
        client.describe = { _ in throw APIError.domain(code: "QUOTA_EXHAUSTED", messages: []) }
        let viewModel = AwaitedEditionViewModel(edition: .preview, client: client)

        await viewModel.describe()

        #expect(viewModel.shown.synopsis == AwaitedEdition.preview.cover.synopsis)
        #expect(viewModel.isDescribing == false)
    }
}

@MainActor
struct AwaitedEditionSagaTests {
    @Test func theCopysSagaHeadsTheEditionAndFillsTheRow() async {
        var client = DiscoverClient.preview
        client.book = { id in
            Book(
                id: id,
                title: "Les Mensonges de Locke Lamora",
                authors: ["Scott Lynch"],
                language: .fr,
                series: SeriesMembership(id: "sg", name: "Les Salauds Gentilshommes", volume: 1, kind: .main),
                status: .read
            )
        }
        client.sagaVolumes = { seriesId, language in
            [.missing(key: "\(seriesId)-2-\(language?.rawValue ?? "none")", number: 2, title: "Des horizons rouges", forthcoming: false)]
        }
        let viewModel = AwaitedEditionViewModel(edition: .preview, client: client)

        await viewModel.loadSaga()

        #expect(viewModel.shown.series?.name == "Les Salauds Gentilshommes")
        #expect(viewModel.shown.series?.volume == 1)
        #expect(viewModel.sagaVolumes.map(\.id) == ["missing-sg-2-fr"])
    }

    @Test func aBookOnItsOwnHasNoRow() async {
        var client = DiscoverClient.preview
        client.book = { id in Book(id: id, title: "Seul", authors: [], status: .read) }
        let viewModel = AwaitedEditionViewModel(edition: .preview, client: client)

        await viewModel.loadSaga()

        #expect(viewModel.sagaName == nil)
        #expect(viewModel.sagaVolumes.isEmpty)
    }
}

@MainActor
struct AnnouncedVolumeBellTests {
    @Test func theBellTurnsAtOnceAndTellsTheServer() async {
        let calls = Calls()
        var client = DiscoverClient.preview
        client.setSagaFollowed = { seriesId, followed in calls.record("\(seriesId) \(followed)") }
        let viewModel = AnnouncedVolumeViewModel(opened: .preview, client: client)

        await viewModel.toggleFollowed()

        #expect(viewModel.isFollowed == false)
        #expect(calls.all == ["dcc false"])
    }

    @Test func aRefusalTurnsTheBellBack() async {
        var client = DiscoverClient.preview
        client.setSagaFollowed = { _, _ in throw APIError.domain(code: "NOT_FOUND", messages: []) }
        let viewModel = AnnouncedVolumeViewModel(opened: .preview, client: client)

        await viewModel.toggleFollowed()

        #expect(viewModel.isFollowed == true)
    }

    @Test func theRowIsTheSagasInItsLanguage() async {
        var client = DiscoverClient.preview
        client.sagaVolumes = { seriesId, language in
            [.missing(key: "\(seriesId)-8-\(language?.rawValue ?? "none")", number: 8, title: "Le Livre du Carnage", forthcoming: true)]
        }
        let viewModel = AnnouncedVolumeViewModel(opened: .preview, client: client)

        await viewModel.loadSaga()

        #expect(viewModel.sagaVolumes.map(\.id) == ["missing-dcc-8-fr"])
    }
}
