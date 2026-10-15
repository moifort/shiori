import SwiftUI

/// A friend's library — or the reader's own, previewed — laid out as the
/// Library tab: the capsule above the bottom edge switches between the books
/// and the sagas, each shelf with its two views and its filter. No authors:
/// a friend's shelf is read through what they hold.
struct FriendShelfScreen: View {
    let friendId: String
    let friendName: String
    var isPreview = false
    var client: FriendsClient = .live

    @State private var shelf: LibraryShelf = .books

    var body: some View {
        Group {
            switch shelf {
            case .books, .authors:
                FriendLibraryScreen(friendId: friendId, friendName: friendName, isPreview: isPreview, client: client)
            case .series:
                FriendSeriesListScreen(friendId: friendId, friendName: friendName, isPreview: isPreview, client: client)
            }
        }
        .libraryShelfPicker($shelf, shelves: [.books, .series])
    }
}

#Preview {
    NavigationStack {
        FriendShelfScreen(friendId: "camille", friendName: "Camille", client: .preview)
    }
}
