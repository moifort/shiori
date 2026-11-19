import Foundation
import Testing
@testable import Shiori

@MainActor
struct FriendsTabViewModelTests {
    @Test func loadShowsEveryFriendAndTheirRails() async {
        let viewModel = FriendsViewModel(client: .preview, caching: false)

        await viewModel.loadOnAppear()

        #expect(viewModel.friends.map(\.userId) == Friend.previews.map(\.userId))
        #expect(viewModel.selected.isEmpty)
        #expect(viewModel.shelf == FriendsShelf.preview)
        #expect(viewModel.soleFriend == nil)
        #expect(viewModel.loaded)
    }

    @Test func pickingAFriendAsksForTheirRailsAlone() async {
        let calls = Calls()
        var client = FriendsClient.preview
        client.friendsShelf = { ids in
            calls.record(ids.joined(separator: ","))
            return FriendsShelf.preview.narrowed(to: ids)
        }
        let viewModel = FriendsViewModel(client: client, caching: false)
        await viewModel.load()

        await viewModel.toggle("camille")

        #expect(viewModel.selected == ["camille"])
        #expect(viewModel.soleFriend?.userId == "camille")
        #expect(viewModel.shelf.reading.allSatisfy { $0.friendId == "camille" })
        #expect(calls.all.last == "camille")
    }

    @Test func twoFriendsPickedHaveNoSoleFriend() async {
        let viewModel = FriendsViewModel(client: .preview, caching: false)
        await viewModel.load()

        await viewModel.toggle("camille")
        await viewModel.toggle("leo")

        #expect(viewModel.selected == ["camille", "leo"])
        #expect(viewModel.soleFriend == nil)
    }

    @Test func lettingEveryFriendGoShowsEveryoneAgain() async {
        let viewModel = FriendsViewModel(client: .preview, caching: false)
        await viewModel.load()

        await viewModel.toggle("camille")
        await viewModel.toggle("camille")

        #expect(viewModel.selected.isEmpty)
        #expect(viewModel.shelf == FriendsShelf.preview)
    }

    @Test func noFriendLoadsTheReadersOwnShelf() async {
        var client = FriendsClient.preview
        client.friends = { [] }
        client.friendsShelf = { _ in FriendsShelf() }
        let viewModel = FriendsViewModel(client: client, caching: false)

        await viewModel.load()

        #expect(viewModel.hasNoFriend)
        #expect(viewModel.myShelf?.userId == FriendProfile.preview.userId)
    }

    @Test func failureOverNothingIsShown() async {
        var client = FriendsClient.preview
        client.friends = { throw Boom() }
        let viewModel = FriendsViewModel(client: client, caching: false)

        await viewModel.load()

        #expect(viewModel.loadFailed != nil)
        #expect(viewModel.loaded == false)
    }

    @Test func failureOverContentKeepsTheRails() async {
        let fails = Flag()
        var client = FriendsClient.preview
        client.friendsShelf = { ids in
            if fails.isOn { throw Boom() }
            return FriendsShelf.preview.narrowed(to: ids)
        }
        let viewModel = FriendsViewModel(client: client, caching: false)
        await viewModel.load()

        fails.isOn = true
        await viewModel.load()

        #expect(viewModel.shelf == FriendsShelf.preview)
        #expect(viewModel.loadFailed == nil)
    }
}
