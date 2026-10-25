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
            // Set as the reader's own hero sets its next step: the symbol
            // in the text's font, six points from it, one height.
            HStack(spacing: 6) {
                Image(systemName: owned ? "checkmark" : "plus")
                    .imageScale(.medium)
                    .accessibilityHidden(true)
                Text(owned ? "Chez vous" : "Ajouter")
            }
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 2)
            .frame(height: 24)
        }
        .menuStyle(.button)
        .buttonStyle(.glassProminent)
        .tint(.white)
        .foregroundStyle(.black)
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
    .font(.subheadline.weight(.semibold))
    .padding()
    .background(.black)
}
