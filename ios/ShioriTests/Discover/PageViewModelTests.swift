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
        client.awaitEdition = { draft, format in calls.record("await \(draft.title) \(format.rawValue)") }
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
