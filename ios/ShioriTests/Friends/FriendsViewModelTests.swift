import Foundation
import Testing
@testable import Shiori

@MainActor
struct FriendShelfListModelTests {
    private static let books = FriendProfile.preview.favorites + FriendProfile.preview.reading

    /// Two pages of the preview books, cut after the third.
    private static var paged: FriendShelfListModel<FriendBook>.Fetch {
        let books = books
        return { after in
            after == nil ? (Array(books.prefix(3)), true) : (Array(books.dropFirst(3)), false)
        }
    }

    @Test func loadShowsTheFirstPageForItsQuery() async {
        let model = FriendShelfListModel<FriendBook>(ownedFlag: \.inLibrary)

        await model.load(query: "all-all", fetch: Self.paged)

        #expect(model.rows.map(\.id) == Self.books.prefix(3).map(\.id))
        #expect(model.hasMore)
        #expect(model.loadedQuery == "all-all")
    }

    @Test func nextPageIsAppendedOnceAfterTheLastRow() async {
        let asked = Calls()
        let model = FriendShelfListModel<FriendBook>(ownedFlag: \.inLibrary)
        await model.load(query: "all-all", fetch: Self.paged)

        let books = Self.books
        await model.loadMore { after in
            asked.record(after ?? "nil")
            // The server sends the last row again: it is kept once.
            return ([books[2]] + books.dropFirst(3), false)
        }

        #expect(asked.all == [Self.books[2].id])
        #expect(model.rows.map(\.id) == Self.books.map(\.id))
        #expect(model.hasMore == false)
    }

    @Test func failedNextPageTurnsIntoARetry() async {
        let model = FriendShelfListModel<FriendBook>(ownedFlag: \.inLibrary)
        await model.load(query: "all-all", fetch: Self.paged)

        await model.loadMore { _ in throw Boom() }

        #expect(model.loadMoreFailed)
        #expect(model.rows.count == 3)
    }

    @Test func cancelledLoadSaysNothing() async {
        let model = FriendShelfListModel<FriendBook>(ownedFlag: \.inLibrary)

        await model.load(query: "all-all") { _ in throw CancellationError() }

        #expect(model.errorMessage == nil)
        #expect(model.loadedQuery == nil)
    }

    @Test func takenRowSaysItIsTheReaders() async {
        let model = FriendShelfListModel<FriendBook>(ownedFlag: \.inLibrary)
        await model.load(query: "all-all", fetch: Self.paged)
        let taken = model.rows[0].id
        #expect(model.rows[0].inLibrary == false)

        await model.take(taken) {}

        #expect(model.rows[0].inLibrary)
        #expect(model.adding.isEmpty)
    }

    @Test func refusedTakeLeavesTheRowAndSaysSo() async {
        let model = FriendShelfListModel<FriendBook>(ownedFlag: \.inLibrary)
        await model.load(query: "all-all", fetch: Self.paged)

        await model.take(model.rows[0].id) { throw Boom() }

        #expect(model.rows[0].inLibrary == false)
        #expect(model.addFailed != nil)
        #expect(model.adding.isEmpty)
    }
}

@MainActor
struct FriendBookViewModelTests {
    @Test func addSaysWhatTheReaderTook() async {
        let viewModel = FriendBookViewModel(friendId: "camille", bookId: "preview", client: .preview, caching: false)

        let added = await viewModel.add(.read, as: .book)

        #expect(added)
        #expect(viewModel.added == .read)
    }

    @Test func refusedAddSaysSo() async {
        var client = FriendsClient.preview
        client.addBook = { _, _, _, _ in throw Boom() }
        let viewModel = FriendBookViewModel(friendId: "camille", bookId: "preview", client: client, caching: false)

        let added = await viewModel.add(.toRead, as: .book)

        #expect(added == false)
        #expect(viewModel.added == nil)
        #expect(viewModel.addFailed != nil)
    }

    @Test func awaitedEditionShowsAtOnceAndGivesWayToTheAnswer() async {
        let viewModel = FriendBookViewModel(friendId: "camille", bookId: "preview", client: .preview, caching: false)
        await viewModel.load()

        viewModel.awaitEdition(.audiobook)

        #expect(viewModel.offer.awaited.count == 1)
        let pending = viewModel.offer.awaited[0]
        await viewModel.stopAwaiting(pending)
        #expect(viewModel.offer.awaited.isEmpty)
    }
}
