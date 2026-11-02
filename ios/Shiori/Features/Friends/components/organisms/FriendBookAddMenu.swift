import SwiftUI

/// The first button of a friend's book hero, where the reader's own book has
/// its next step: onto the pile, or among the books read, in print or as a
/// recording — a reader who never listens takes a friend's recording as a
/// book, and a printed book is offered heard once Audible confirms it sells
/// it. Its edition in the app's language, translated or recorded, may be
/// awaited from here too. Once the reader holds the book it says so, "✓ Chez
/// vous", and still opens what is left to await; greyed out once nothing is.
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
                        Button(
                            format == .audiobook ? "À écouter" : "À lire",
                            systemImage: "bookmark.fill"
                        ) {
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
            Label(
                owned ? "Chez vous" : "Ajouter",
                systemImage: owned ? "checkmark" : "plus"
            )
            .font(.headline)
            .lineLimit(1)
            .fixedSize()
        }
        .menuStyle(.button)
        .buttonStyle(.heroProminent)
        .opacity(owned && awaitable.isEmpty ? 0.45 : 1)
        .disabled(owned && awaitable.isEmpty)
        .accessibilityLabel(owned ? Text("Chez vous") : Text("Ajouter à ma bibliothèque"))
        .accessibilityIdentifier("friend-book-add-menu")
    }
}

#Preview {
    VStack(spacing: 20) {
        FriendBookAddMenu(
            formats: [.book, .audiobook], owned: false, awaitable: [.audiobook],
            onAdd: { _, _ in }, onAwait: { _ in }
        )
        FriendBookAddMenu(formats: [.book], owned: true, awaitable: [], onAdd: { _, _ in }, onAwait: { _ in })
    }
    .padding()
    .background(.black)
}
