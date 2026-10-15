import Foundation
import Testing
@testable import Shiori

@MainActor
struct SharedViewModelTests {
    @Test func loadShowsTheShelfAndTheFriends() async {
        let viewModel = SharedViewModel(client: .preview, caching: false)
        #expect(viewModel.isEmpty)

        await viewModel.loadOnAppear()

        #expect(viewModel.friends.map(\.userId) == Friend.previews.map(\.userId))
        #expect(viewModel.myShelf?.userId == FriendProfile.preview.userId)
        #expect(viewModel.loaded)
        #expect(viewModel.loadFailed == nil)
    }

    @Test func failureOverNothingIsShown() async {
        var client = FriendsClient.preview
        client.friends = { throw Boom() }
        client.myShelf = { throw Boom() }
        let viewModel = SharedViewModel(client: client, caching: false)

        await viewModel.load()

        #expect(viewModel.isEmpty)
        #expect(viewModel.loadFailed != nil)
        #expect(viewModel.loaded == false)
    }

    @Test func failureOverContentKeepsTheRows() async {
        let fails = Flag()
        var client = FriendsClient.preview
        client.friends = {
            if fails.isOn { throw Boom() }
            return Friend.previews
        }
        let viewModel = SharedViewModel(client: client, caching: false)
        await viewModel.load()

        fails.isOn = true
        await viewModel.load()

        #expect(viewModel.friends.map(\.userId) == Friend.previews.map(\.userId))
    }

    @Test func acceptFilesTheFriendByFirstName() async {
        var client = FriendsClient.preview
        client.friends = { [Friend.previews[1]] }
        client.accept = { _ in Friend.previews[0] }
        let viewModel = SharedViewModel(client: client, caching: false)
        await viewModel.load()

        await viewModel.accept(code: "  K7Q2MX9P \n")

        #expect(viewModel.accepted == Friend.previews[0].displayName)
        #expect(viewModel.friends.map(\.firstName) == ["Camille", "Léo"])
    }

    @Test func acceptAsksNothingOfAnEmptyCode() async {
        let calls = Calls()
        var client = FriendsClient.preview
        client.accept = { code in
            calls.record(code)
            return Friend.previews[0]
        }
        let viewModel = SharedViewModel(client: client, caching: false)

        await viewModel.accept(code: "   ")

        #expect(calls.all.isEmpty)
        #expect(viewModel.accepted == nil)
    }

    @Test func removeTakesTheFriendOff() async {
        let viewModel = SharedViewModel(client: .preview, caching: false)
        await viewModel.load()

        await viewModel.remove(Friend.previews[1])

        #expect(viewModel.friends.map(\.userId) == [Friend.previews[0].userId])
    }

    @Test func refusedRemoveKeepsTheFriendAndSaysSo() async {
        var client = FriendsClient.preview
        client.remove = { _ in throw Boom() }
        let viewModel = SharedViewModel(client: client, caching: false)
        await viewModel.load()

        await viewModel.remove(Friend.previews[1])

        #expect(viewModel.friends.count == Friend.previews.count)
        #expect(viewModel.errorMessage != nil)
    }
}

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
struct FriendProfileViewModelTests {
    @Test func previewAsksNothing() async {
        let viewModel = FriendProfileViewModel(preview: .preview)

        await viewModel.load()

        #expect(viewModel.isPreview)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.profile?.userId == FriendProfile.preview.userId)
    }

    @Test func failureOverAShelfSaysNothing() async {
        let fails = Flag()
        var client = FriendsClient.preview
        client.profile = { _ in
            if fails.isOn { throw Boom() }
            return .preview
        }
        let viewModel = FriendProfileViewModel(friend: Friend.previews[0], client: client, caching: false)
        await viewModel.load()

        fails.isOn = true
        await viewModel.load()

        #expect(viewModel.profile != nil)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func failureOverNothingIsShown() async {
        var client = FriendsClient.preview
        client.profile = { _ in throw Boom() }
        let viewModel = FriendProfileViewModel(friend: Friend.previews[0], client: client, caching: false)

        await viewModel.load()

        #expect(viewModel.profile == nil)
        #expect(viewModel.errorMessage != nil)
    }

    @Test func ownedBookIsMarkedOnEveryShelf() async {
        let viewModel = FriendProfileViewModel(friend: Friend.previews[0], client: .preview, caching: false)
        await viewModel.load()
        // Silo is on the pile and is the last book added.
        viewModel.markOwned("silo")

        #expect(viewModel.profile?.pile.first { $0.id == "silo" }?.inLibrary == true)
        #expect(viewModel.profile?.lastAdded?.inLibrary == true)
    }
}

@MainActor
struct FriendBookViewModelTests {
    @Test func addSaysWhatTheReaderTook() async {
        let viewModel = FriendBookViewModel(friendId: "camille", bookId: "preview", client: .preview)

        let added = await viewModel.add(.read, as: .book)

        #expect(added)
        #expect(viewModel.added == .read)
    }

    @Test func refusedAddSaysSo() async {
        var client = FriendsClient.preview
        client.addBook = { _, _, _, _ in throw Boom() }
        let viewModel = FriendBookViewModel(friendId: "camille", bookId: "preview", client: client)

        let added = await viewModel.add(.toRead, as: .book)

        #expect(added == false)
        #expect(viewModel.added == nil)
        #expect(viewModel.addFailed != nil)
    }

    @Test func awaitedEditionShowsAtOnceAndGivesWayToTheAnswer() async {
        let viewModel = FriendBookViewModel(friendId: "camille", bookId: "preview", client: .preview)
        await viewModel.load()

        viewModel.awaitEdition(.audiobook)

        #expect(viewModel.offer.awaited.count == 1)
        let pending = viewModel.offer.awaited[0]
        await viewModel.stopAwaiting(pending)
        #expect(viewModel.offer.awaited.isEmpty)
    }
}
