import SwiftUI

/// Everything a friend's book page can ask for.
enum FriendBookAction {
    /// The saga the book belongs to, pushed inside the sheet.
    case openSeries
    case stopAwaiting(AwaitedEdition)
}

/// What a friend's book page draws once the book is known: the reader's own
/// book page, read-only — the friend's status, the book with where it stands
/// for the reader pinned on its cover, the editions awaited, the friend's
/// reading, and the summary.
struct FriendBookPage: View {
    let entry: FriendBook
    /// The friend whose shelf it is: their saga opens as they hold it.
    let friendId: String
    let friendName: String
    /// What the reader just did with it from the "+" in the corner.
    let added: CopiedStatus?
    let awaited: [AwaitedEdition]
    let onAction: (FriendBookAction) async -> Void

    /// Where the book stands for the reader, pinned on its cover: just added
    /// from the "+" in the corner, or held already, which is why the "+" is
    /// greyed out.
    private var state: BookState? {
        switch added {
        case .toRead: .addedToPile
        case .read: .addedAsRead
        case nil: entry.inLibrary ? .owned : nil
        }
    }

    var body: some View {
        List {
            // Laid out as the reader's own page, row for row, so a book reads
            // the same on either shelf: where it stands, what it is, how it
            // was read, what it is about. Only what cannot be done here goes.
            BookStatusSection(status: entry.book.status)
            BookHeaderSection(
                book: entry.book,
                state: state,
                actions: .init(openSeries: { Task { await onAction(.openSeries) } })
            )
            AwaitedEditionsSection(awaited: awaited) { edition in Task { await onAction(.stopAwaiting(edition)) } }
            BookReadingSection(
                title: "Lecture de \(friendName)",
                book: entry.book,
                footer: state == nil
                    ? "Le livre sera noté « Conseillé par \(friendName) ». Sa note de lecture reste privée."
                    : nil
            ) {
                if entry.book.favorite {
                    Label {
                        Text("Coup de cœur")
                    } icon: {
                        Image(systemName: "heart.fill").foregroundStyle(.red)
                    }
                    .accessibilityIdentifier("friend-book-favorite")
                }
            }
            if let synopsis = entry.book.synopsis, !synopsis.isEmpty {
                BookSynopsisSection(synopsis: synopsis)
            }
        }
        .listStyle(.insetGrouped)
        .labelStyle(.row)
    }
}

#Preview("Friend's book held already") {
    NavigationStack {
        FriendBookPage(entry: .preview, friendId: "preview", friendName: "Camille", added: nil, awaited: []) { _ in }
            .navigationTitle("Chez Camille")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Just added to the pile") {
    var entry = FriendBook.preview
    entry.inLibrary = false
    return NavigationStack {
        FriendBookPage(entry: entry, friendId: "preview", friendName: "Camille", added: .toRead, awaited: []) { _ in }
    }
}
