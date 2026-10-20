import Foundation
import Testing
@testable import Shiori

private func book(_ id: String, _ title: String, status: ReadingStatus = .read, favorite: Bool = false) -> Book {
    var book = Book(id: id, title: title, authors: ["Auteur"], status: status)
    book.favorite = favorite
    book.coverURL = URL(string: "https://covers.example/\(id).jpg")
    return book
}

private let shelf = [
    book("carl", "Dungeon Crawler Carl", status: .reading, favorite: true),
    book("vent", "Le Nom du vent"),
    book("peur", "La Peur du sage", status: .toRead),
]

/// Answers with the shelf, counting the index requests and recording the
/// covers asked for.
private func serving(_ books: [Book] = shelf, indexCalls: Calls = Calls(), covers: Calls = Calls(), fails: Flag = Flag()) -> LibrarySearchClient {
    let answering = LibrarySearchClient.answering(books)
    return LibrarySearchClient(
        index: {
            indexCalls.record("index")
            if fails.isOn { throw Boom() }
            return try await answering.index()
        },
        covers: { ids in
            covers.record(ids.joined(separator: ","))
            return try await answering.covers(ids)
        }
    )
}

private func viewedStore() -> RecentlyViewed {
    let suite = "viewed-tests-\(UUID().uuidString)"
    return RecentlyViewed(key: "viewed", defaults: { UserDefaults(suiteName: suite)! })
}

private func recents() -> RecentSearches {
    let suite = "search-tests-\(UUID().uuidString)"
    return RecentSearches(key: "recents", defaults: { UserDefaults(suiteName: suite)! })
}

@MainActor
struct LibrarySearchViewModelTests {
    @Test func preparesUntilTheFirstIndexArrives() async {
        let index = LibrarySearchIndex(client: serving(), caching: false)
        let viewModel = LibrarySearchViewModel(index: index, client: serving(), recents: recents(), coverDelay: .zero)
        #expect(viewModel.isPreparing)

        await viewModel.appear()

        #expect(!viewModel.isPreparing)
        viewModel.query = "carl"
        #expect(viewModel.results.books.map(\.id) == ["carl"])
    }

    @Test func aFailedFirstLoadOffersARetry() async {
        let fails = Flag()
        fails.isOn = true
        let index = LibrarySearchIndex(client: serving(fails: fails), caching: false)
        let viewModel = LibrarySearchViewModel(index: index, client: serving(), recents: recents(), coverDelay: .zero)

        await viewModel.appear()
        #expect(viewModel.failed)

        fails.isOn = false
        await viewModel.retry()
        #expect(!viewModel.failed)
        #expect(!viewModel.isPreparing)
    }

    @Test func aFreshIndexIsNotAskedAgain() async {
        let calls = Calls()
        let index = LibrarySearchIndex(client: serving(indexCalls: calls), caching: false)
        await index.refreshIfNeeded()

        await index.refreshIfNeeded()

        #expect(calls.all.count == 1)
    }

    @Test func aStaleIndexIsAskedAgain() async {
        let calls = Calls()
        let index = LibrarySearchIndex(client: serving(indexCalls: calls), caching: false)
        await index.refreshIfNeeded()

        index.markStale()
        await index.refreshIfNeeded()

        #expect(calls.all.count == 2)
    }

    @Test func anHourOldIndexIsAskedAgain() async {
        let calls = Calls()
        let clock = Clock()
        let index = LibrarySearchIndex(client: serving(indexCalls: calls), caching: false, now: { clock.now })
        await index.refreshIfNeeded()

        clock.now += LibrarySearchIndex.freshFor + 1
        await index.refreshIfNeeded()

        #expect(calls.all.count == 2)
    }

    @Test func forgetsTheAccountSignedOut() async {
        let index = await SearchFixtures.readyIndex(shelf)

        index.forget()

        #expect(index.entries.isEmpty)
        #expect(!index.isReady)
    }

    @Test func filtersCombineAndAStatusTogglesOff() async {
        let index = await SearchFixtures.readyIndex(shelf)
        let viewModel = LibrarySearchViewModel(index: index, client: serving(), recents: recents(), coverDelay: .zero)
        await viewModel.appear()

        viewModel.toggleFavorites()
        viewModel.select(.reading)
        #expect(viewModel.results.books.map(\.id) == ["carl"])

        viewModel.select(.reading)
        #expect(viewModel.filter == SearchFilter(favorites: true, status: nil))
    }

    @Test func countsWhatTheFilterHides() async {
        let index = await SearchFixtures.readyIndex(shelf)
        let viewModel = LibrarySearchViewModel(index: index, client: serving(), recents: recents(), coverDelay: .zero)
        await viewModel.appear()

        viewModel.filter = SearchFilter(favorites: true)
        viewModel.query = "vent"

        #expect(viewModel.results.books.isEmpty)
        #expect(viewModel.results.hiddenByFilter == 1)
    }

    @Test func asksForAtMostFiftyCovers() async throws {
        let many = (0..<80).map { book("b\($0)", "Livre \($0)") }
        let asked = Calls()
        let index = await SearchFixtures.readyIndex(many)
        let viewModel = LibrarySearchViewModel(index: index, client: serving(many, covers: asked), recents: recents(), coverDelay: .zero)
        await viewModel.appear()

        viewModel.query = "livre"
        await eventually { !viewModel.covers.isEmpty }

        let batches = asked.all.map { $0.split(separator: ",").count }
        #expect(batches.allSatisfy { $0 <= LibrarySearchViewModel.coverBatch })
        #expect(viewModel.covers.count == LibrarySearchViewModel.coverBatch)
    }

    @Test func remembersTheQueriesAResultWasOpenedFrom() async {
        let index = await SearchFixtures.readyIndex(shelf)
        let viewModel = LibrarySearchViewModel(index: index, client: serving(), recents: recents(), coverDelay: .zero)

        for query in ["un", "deux", "trois", "quatre", "cinq", "six", "deux"] {
            viewModel.query = query
            viewModel.opened()
        }

        #expect(viewModel.recentSearches == ["deux", "six", "cinq", "quatre", "trois"])
    }
}

extension LibrarySearchViewModelTests {
    @Test func offersTheBooksViewedLastAndDropsOnesGone() async {
        let viewed = viewedStore()
        for id in ["vent", "gone", "carl"] { viewed.remember(id) }
        viewed.remember("vent")
        let index = await SearchFixtures.readyIndex(shelf)
        let viewModel = LibrarySearchViewModel(index: index, client: serving(), recents: recents(), viewed: viewed, coverDelay: .zero)

        await viewModel.appear()

        #expect(viewModel.recentlyViewed.map(\.id) == ["vent", "carl"])
    }

    @Test func keepsTenViewedBooksAtMost() {
        let viewed = viewedStore()
        for index in 0..<12 { viewed.remember("b\(index)") }
        #expect(viewed.ids.count == RecentlyViewed.limit)
        #expect(viewed.ids.first == "b11")
    }

    @Test func clearsTheRecentSearches() async {
        let index = await SearchFixtures.readyIndex(shelf)
        let store = recents()
        store.remember("carl")
        let viewModel = LibrarySearchViewModel(index: index, client: serving(), recents: store, coverDelay: .zero)

        viewModel.clearRecentSearches()

        #expect(viewModel.recentSearches.isEmpty)
        #expect(store.all.isEmpty)
    }
}

private final class Clock: @unchecked Sendable {
    private let lock = NSLock()
    private var value = Date(timeIntervalSince1970: 1_800_000_000)

    var now: Date {
        get { lock.withLock { value } }
        set { lock.withLock { value = newValue } }
    }
}
