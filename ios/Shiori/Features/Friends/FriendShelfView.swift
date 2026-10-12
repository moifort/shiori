import SwiftUI

/// A friend's library — or the reader's own, previewed — laid out as the
/// Library tab: the capsule above the bottom edge switches between the books
/// and the sagas, each shelf with its two views and its filter. No authors:
/// a friend's shelf is read through what they hold.
struct FriendShelfView: View {
    let friendId: String
    let friendName: String
    var isPreview = false

    @State private var shelf: LibraryShelf = .books

    var body: some View {
        Group {
            switch shelf {
            case .books, .authors:
                FriendLibraryView(friendId: friendId, friendName: friendName, isPreview: isPreview)
            case .series:
                FriendSeriesListView(friendId: friendId, friendName: friendName, isPreview: isPreview)
            }
        }
        .libraryShelfPicker($shelf, shelves: [.books, .series])
    }
}
