import SwiftUI

/// The "+" in the corner of a friend's book: onto the pile, or among the books
/// read, in print or as a recording — a reader who never listens takes a
/// friend's recording as a book, and a printed book is offered heard once
/// Audible confirms it sells it. Its edition in the app's language, translated
/// or recorded, may be awaited from here too. Greyed out once nothing is left
/// to do.
struct FriendBookAddMenu: View {
    /// The formats the reader may take the book in.
    let formats: [BookFormat]
    /// The reader holds the book already, or just took it.
    let owned: Bool
    /// The editions the reader may await.
    let awaitable: [ReleaseFormat]
    let onAdd: (CopiedStatus, BookFormat) async -> Void
    let onAwait: (ReleaseFormat) -> Void

    var body: some View {
        Menu {
            if !owned {
                ForEach(formats, id: \.self) { format in
                    Section(format.label) {
                        Button("À lire", systemImage: "bookmark.fill") {
                            Task { await onAdd(.toRead, format) }
                        }
                        .accessibilityIdentifier("friend-book-add-pile-\(format.rawValue)")
                        Button(
                            format == .audiobook ? "Déjà écouté" : "Déjà lu",
                            systemImage: "checkmark"
                        ) {
                            Task { await onAdd(.read, format) }
                        }
                        .accessibilityIdentifier("friend-book-add-read-\(format.rawValue)")
                    }
                }
            }
            if !awaitable.isEmpty {
                Section {
                    ForEach(awaitable) { format in
                        Button(
                            format.awaitLabel,
                            systemImage: format == .audiobook ? "headphones" : "character.book.closed"
                        ) {
                            onAwait(format)
                        }
                        .accessibilityIdentifier("friend-book-await-\(format.rawValue)")
                    }
                }
            }
        } label: {
            Label("Ajouter à ma bibliothèque", systemImage: "plus")
        }
        .disabled(owned && awaitable.isEmpty)
        .accessibilityIdentifier("friend-book-add-menu")
    }
}

#Preview {
    NavigationStack {
        Text(verbatim: "Chez Camille")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    FriendBookAddMenu(
                        formats: [.book, .audiobook], owned: false, awaitable: [.audiobook],
                        onAdd: { _, _ in }, onAwait: { _ in }
                    )
                }
            }
    }
}
