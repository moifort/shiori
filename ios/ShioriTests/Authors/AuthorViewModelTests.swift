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
        let saga = AuthorPage.preview.sagasNotHeld[0]

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

    @Test func correctionDrawsThePageTheServerAnswers() async {
        let sent = Calls()
        let base = AuthorPage.preview
        let corrected = AuthorPage(
            author: base.author,
            readCount: base.readCount,
            nationality: base.nationality,
            birthYear: base.birthYear,
            deathYear: base.deathYear,
            biography: "Autrice de l'Assassin royal.",
            sagas: base.sagas,
            sagasNotHeld: base.sagasNotHeld,
            books: base.books,
            booksNotHeld: base.booksNotHeld
        )
        var client = AuthorsClient.preview
        client.correct = { [corrected] _, correction in
            if case let .set(text) = correction.biography { sent.record(text) }
            return corrected
        }
        let viewModel = model(client)
        await viewModel.load()

        let failure = await viewModel.correct(PersonCorrection(biography: .set("Autrice de l'Assassin royal.")))

        #expect(failure == nil)
        #expect(sent.all == ["Autrice de l'Assassin royal."])
        #expect(viewModel.page?.biography == "Autrice de l'Assassin royal.")
    }

    @Test func failedCorrectionLeavesThePageAndSaysWhy() async {
        var client = AuthorsClient.preview
        client.correct = { _, _ in throw Boom() }
        let viewModel = model(client)
        await viewModel.load()

        let failure = await viewModel.correct(PersonCorrection(nationality: .clear))

        #expect(failure != nil)
        #expect(viewModel.page?.nationality == AuthorPage.preview.nationality)
    }
}

@MainActor
struct AuthorListViewModelTests {
    @Test func loadShowsTheAuthors() async {
        let viewModel = AuthorListViewModel(client: .preview, caching: false)

        await viewModel.load()

        #expect(viewModel.people.map(\.key) == FollowedAuthor.previews.map(\.key))
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

        #expect(viewModel.people.count == FollowedAuthor.previews.count)
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

        let ids = viewModel.people.map(\.id)
        #expect(ids.count == FollowedAuthor.previews.count)
        #expect(cursors.all == ["top"] + ids.dropLast())
    }
}
