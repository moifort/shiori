import Foundation
import Testing
@testable import Shiori

/// Five books shelved one day apart, the newest first, as the server orders them.
private let shelf: [Book] = (0..<5).map { index in
    var book = Book(id: "b\(index)", title: "Livre \(index)", authors: ["Auteur"], status: .read)
    book.shelvedAt = Date(timeIntervalSince1970: 1_800_000_000 - Double(index) * 86_400)
    return book
}

/// The shelf served by cursor, at most `cap` books a page.
private func serving(cap: Int = .max, asked: Calls? = nil) -> LibraryClient {
    LibraryClient(
        page: { _, _, limit, after in
            asked?.record(after ?? "start")
            let start = after.flatMap { id in shelf.firstIndex { $0.id == id }.map { $0 + 1 } } ?? 0
            let page = Array(shelf.dropFirst(start).prefix(min(limit, cap)))
            return LibraryPageResult(books: page, hasMore: start + page.count < shelf.count)
        },
        awaited: { _ in [] }
    )
}

@MainActor
struct LibraryViewModelTests {
    @Test func cappedPagesFollowTheLastBook() async {
        let asked = Calls()
        let viewModel = LibraryViewModel(client: serving(cap: 2, asked: asked), caching: false)

        await viewModel.load()

        #expect(viewModel.books.map(\.id) == shelf.map(\.id))
        #expect(asked.all == ["start", "b1", "b3"])
        #expect(viewModel.hasMore == false)
    }

    @Test func failureOverRowsKeepsThem() async {
        let fails = Flag()
        let served = serving()
        let viewModel = LibraryViewModel(
            client: LibraryClient(
                page: { mode, filter, limit, after in
                    if fails.isOn { throw Boom() }
                    return try await served.page(mode, filter, limit, after)
                },
                awaited: { _ in [] }
            ),
            caching: false
        )
        await viewModel.load()

        fails.isOn = true
        await viewModel.load()

        #expect(viewModel.books.count == shelf.count)
    }

    @Test func editedBookMovesWhereTheServerWouldShelveIt() async {
        let viewModel = LibraryViewModel(client: serving(), caching: false)
        await viewModel.load()
        var finished = shelf[3]
        finished.finishedAt = Date(timeIntervalSince1970: 1_900_000_000)

        viewModel.apply(finished)

        #expect(viewModel.books.first?.id == "b3")
        #expect(viewModel.books.count == shelf.count)
    }

    @Test func bookNoLongerInTheFilterLeavesIt() async {
        let viewModel = LibraryViewModel(client: serving(), caching: false)
        viewModel.filter = .status(.read)
        await viewModel.load()
        var dropped = shelf[1]
        dropped.status = .dropped

        viewModel.apply(dropped)

        #expect(!viewModel.books.contains { $0.id == "b1" })
    }

    @Test func bookUnheartedLeavesTheFavorites() async {
        let viewModel = LibraryViewModel(client: serving(), caching: false)
        viewModel.filter = .favorites
        await viewModel.load()
        var unhearted = shelf[2]
        unhearted.favorite = false

        viewModel.apply(unhearted)

        #expect(!viewModel.books.contains { $0.id == "b2" })
    }

    @Test func requestOpensTheListByDate() {
        let viewModel = LibraryViewModel(client: serving(), caching: false)
        viewModel.mode = .favorites

        viewModel.show(LibraryRequest(filter: .favorites))

        #expect(viewModel.mode == .all)
        #expect(viewModel.filter == .favorites)
        #expect(viewModel.layout == .list)
    }

    @Test func awaitedBooksAreMarked() async {
        let edition = AwaitedEdition.pending(format: .audiobook, of: shelf[0])
        let viewModel = LibraryViewModel(
            client: LibraryClient(page: serving().page, awaited: { format in format == .audiobook ? [edition] : [] }),
            caching: false
        )

        await viewModel.loadAwaited()

        #expect(viewModel.awaitedBookIds == Set([edition.bookId].compactMap(\.self)))
    }
}
