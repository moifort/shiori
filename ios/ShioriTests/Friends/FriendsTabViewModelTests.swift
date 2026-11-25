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

    @Test func aFriendAskedForFromDecouvrirIsShownAlone() async {
        let viewModel = FriendsViewModel(client: .preview, caching: false)
        await viewModel.load()
        await viewModel.toggle("camille")
        await viewModel.toggle("leo")

        await viewModel.show(only: "leo")

        #expect(viewModel.selected == ["leo"])
        #expect(viewModel.soleFriend?.userId == "leo")
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

    @Test func removingAFriendDropsThemFromTheAvatarsAndThePick() async {
        let calls = Calls()
        var client = FriendsClient.preview
        client.remove = { id in calls.record(id) }
        let viewModel = FriendsViewModel(client: client, caching: false)
        await viewModel.load()
        await viewModel.toggle("camille")

        await viewModel.remove("camille")

        #expect(calls.all == ["camille"])
        #expect(!viewModel.friends.contains { $0.userId == "camille" })
        #expect(viewModel.selected.isEmpty)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func refusedRemovalKeepsTheFriendAndSaysSo() async {
        var client = FriendsClient.preview
        client.remove = { _ in throw Boom() }
        let viewModel = FriendsViewModel(client: client, caching: false)
        await viewModel.load()

        await viewModel.remove("camille")

        #expect(viewModel.friends.contains { $0.userId == "camille" })
        #expect(viewModel.errorMessage != nil)
    }

    @Test func anOnlyFriendIsPickedAndOpensTheirLibrary() async {
        var client = FriendsClient.preview
        client.friends = { [Friend.previews[0]] }
        let viewModel = FriendsViewModel(client: client, caching: false)

        await viewModel.load()

        #expect(viewModel.picked == [Friend.previews[0].userId])
        #expect(viewModel.soleFriend?.userId == Friend.previews[0].userId)
    }

    @Test func anOnlyFriendCannotBeLetGo() async {
        var client = FriendsClient.preview
        client.friends = { [Friend.previews[0]] }
        let viewModel = FriendsViewModel(client: client, caching: false)
        await viewModel.load()

        await viewModel.toggle(Friend.previews[0].userId)

        #expect(viewModel.selected.isEmpty)
        #expect(viewModel.soleFriend?.userId == Friend.previews[0].userId)
    }

    @Test func removingTheSecondToLastFriendLeavesTheOtherPicked() async {
        let viewModel = FriendsViewModel(client: .preview, caching: false)
        await viewModel.load()
        let others = Friend.previews.dropFirst().map(\.userId)
        await viewModel.toggle(others[0])

        for id in others { await viewModel.remove(id) }

        #expect(viewModel.selected.isEmpty)
        #expect(viewModel.soleFriend?.userId == Friend.previews[0].userId)
    }

    @Test func aSecondFriendArrivingShowsEveryoneAgain() async {
        let friendsNow = Box([Friend.previews[0]])
        var client = FriendsClient.preview
        client.friends = { friendsNow.value }
        let viewModel = FriendsViewModel(client: client, caching: false)
        await viewModel.load()
        await viewModel.show(only: Friend.previews[0].userId)

        friendsNow.value = Array(Friend.previews.prefix(2))
        await viewModel.load()

        #expect(viewModel.picked.isEmpty)
        #expect(viewModel.soleFriend == nil)
    }

    @Test func removingTheOnlyFriendLeavesTheInvitation() async {
        let friendsNow = Box([Friend.previews[0]])
        var client = FriendsClient.preview
        client.friends = { friendsNow.value }
        client.remove = { _ in friendsNow.value = [] }
        let viewModel = FriendsViewModel(client: client, caching: false)
        await viewModel.load()

        await viewModel.remove(Friend.previews[0].userId)

        #expect(viewModel.hasNoFriend)
        #expect(viewModel.picked.isEmpty)
        #expect(viewModel.soleFriend == nil)
    }
}

/// A value the test changes under a client closure.
private final class Box<Value>: @unchecked Sendable {
    var value: Value
    init(_ value: Value) { self.value = value }
}
