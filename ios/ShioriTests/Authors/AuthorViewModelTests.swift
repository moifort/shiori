import Foundation
import Testing
@testable import Shiori

@MainActor
struct AuthorViewModelTests {
    private func model(_ client: AuthorsClient = .preview, offered: Bool = false) -> AuthorViewModel {
        AuthorViewModel(key: "robin hobb", name: "Robin Hobb", isOffered: offered, client: client)
    }

    @Test func offeredAuthorIsAskedByName() async {
        let asked = Calls()
        var client = AuthorsClient.preview
        client.page = { _, offered in
            asked.record(offered ?? "nil")
            return .preview
        }

        await model(client).load()
        await model(client, offered: true).load()

        #expect(asked.all == ["nil", "Robin Hobb"])
    }

    @Test func authorAwaitingTheCatalogueIsBuiltWhileTheBooksShow() async {
        var awaiting = AuthorPage.preview
        awaiting.isAwaitingCatalogue = true
        var client = AuthorsClient.preview
        client.page = { [awaiting] _, _ in awaiting }
        client.catalogue = { _, _ in .preview }
        let viewModel = model(client)
        await viewModel.load()
        #expect(viewModel.page?.isAwaitingCatalogue == true)

        await viewModel.buildCatalogueIfAwaiting()

        #expect(viewModel.page?.isAwaitingCatalogue == false)
        #expect(viewModel.isGenerating == false)
    }

    @Test func pageWithoutReleasesStillShows() async {
        var client = AuthorsClient.preview
        client.releases = { _ in throw Boom() }
        let viewModel = model(client)

        await viewModel.load()

        #expect(viewModel.page != nil)
        #expect(viewModel.releases.isEmpty)
    }

    @Test func sagaStartsWithItsFirstVolumeInTheSaga() async {
        let asked = Calls()
        var client = AuthorsClient.preview
        client.addBook = { draft, _ in
            asked.record("\(draft.title) \(draft.series?.volume ?? 0) \(draft.format.rawValue)")
            return .preview
        }
        let viewModel = model(client)
        let saga = AuthorPage.preview.printSagasNotHeld[0]

        await viewModel.start(saga, author: "Robin Hobb", format: .audio)

        #expect(asked.all == ["Le Vaisseau magique 1 audiobook"])
        #expect(viewModel.adding == nil)
    }

    @Test func refusedAddSaysSo() async {
        var client = AuthorsClient.preview
        client.addBook = { _, _ in throw Boom() }
        let viewModel = model(client)

        await viewModel.add(AuthorPage.preview.booksNotHeld[0], author: "Robin Hobb", format: .print)

        #expect(viewModel.errorMessage != nil)
    }
}

@MainActor
struct AuthorListViewModelTests {
    @Test func loadShowsTheAuthors() async {
        let viewModel = AuthorListViewModel(client: .preview, caching: false)

        await viewModel.load()

        #expect(viewModel.authors.map(\.key) == FollowedAuthor.previews.map(\.key))
    }

    @Test func failureOverRowsKeepsThem() async {
        let fails = Flag()
        var client = AuthorsClient.preview
        client.list = { limit, after, order in
            if fails.isOn { throw Boom() }
            return try await AuthorsClient.preview.list(limit, after, order)
        }
        let viewModel = AuthorListViewModel(client: client, caching: false)
        await viewModel.load()

        fails.isOn = true
        await viewModel.load()

        #expect(viewModel.authors.count == FollowedAuthor.previews.count)
    }

    @Test func cappedPagesFollowOneAnother() async {
        let cursors = Calls()
        var client = AuthorsClient.preview
        client.list = { _, after, order in
            cursors.record(after ?? "top")
            return try await AuthorsClient.preview.list(1, after, order)
        }
        let viewModel = AuthorListViewModel(client: client, caching: false)

        await viewModel.load()

        let ids = viewModel.authors.map(\.id)
        #expect(ids.count == FollowedAuthor.previews.count)
        #expect(cursors.all == ["top"] + ids.dropLast())
    }
}
