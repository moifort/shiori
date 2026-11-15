import SwiftUI

/// A book wished for, drawn as a book to have is (`UnownedBookPage`): the
/// hero over the cover's colours, where it came from on the detail line, the
/// white button that orders it from its store and the "+" that puts it on
/// the pile or among the books read, and "Plus intéressé" that takes it off
/// the list. Then its summary and its facts. No bell: nothing is awaited. Pure and previewable.
struct WishPage: View {
    let wish: Wish
    /// The wish once described, as a book's page draws it.
    let shown: Book
    let storeURL: URL?
    let isDescribing: Bool
    /// False when the page is pushed: Back closes it, not a Close button.
    var showsClose = true
    var onClose: () -> Void = {}
    let onAdd: (ReadingStatus) async -> Void
    let onRemove: () async -> Void

    var body: some View {
        UnownedBookPage(
            book: shown,
            releaseDate: nil,
            isDescribing: isDescribing,
            store: storeURL.map { UnownedBookStore(url: $0, isAudible: wish.format == .audiobook) },
            isAlerted: false,
            state: BookState(text: wish.originLine, tint: .gray),
            isOut: true,
            isAdded: false,
            showsClose: showsClose,
            onClose: onClose,
            additions: [.pile, .read],
            onAdd: { addition in await onAdd(addition == .read ? .read : .toRead) },
            onToggleBell: {},
            onNoLongerInterested: onRemove
        )
    }
}

#if DEBUG
#Preview {
    let wish = Wish.previews[0]
    NavigationStack {
        WishPage(
            wish: wish,
            shown: wish.release.book(id: wish.id),
            storeURL: URL(string: "https://www.amazon.fr/s?k=Piranesi"),
            isDescribing: false,
            onAdd: { _ in },
            onRemove: {}
        )
    }
}
#endif
