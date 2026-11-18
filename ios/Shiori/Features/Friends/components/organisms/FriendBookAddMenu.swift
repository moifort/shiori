import SwiftUI

/// The first buttons of a friend's book hero, where the reader's own book has
/// its next step: "Envies" and the "+" beside it, onto the pile, or among the books read, in print or as a
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
    /// On the reader's wishlist already, from this menu.
    var wished = false
    let onAwait: (ReleaseFormat) -> Void
    var onWish: () async -> Void = {}
    /// What may be awaited and what is, drawn as "Guetter" beside "Envies"
    /// while the reader does not hold the book; nil keeps the editions in the
    /// "+".
    var watch: EditionWatch? = nil
    /// "Guetter" pressed on an edition awaited: it is given up.
    var onStopAwaiting: (ReleaseFormat) -> Void = { _ in }
    /// "Envies" as the bookmark alone, for a row that holds the friend's
    /// mark beside "Guetter".
    var isCompact = false

    var body: some View {
        if owned {
            heldMenu
        } else {
            // The pair every book page shares: "Envies", a second tap taking
            // the book back off, and the "+" of the same items, wish list aside.
            WishAddButtons(
                isWished: wished,
                size: .page,
                isCompact: isCompact,
                showsMenu: !formats.isEmpty || (watch == nil && !awaitable.isEmpty),
                watch: watch,
                onAwait: { format in
                    if watch?.awaited.contains(format) == true { onStopAwaiting(format) } else { onAwait(format) }
                },
                onToggle: { Task { await onWish() } }
            ) {
                BookAddMenuItems(
                    formats: formats,
                    owned: false,
                    awaitable: watch == nil ? awaitable : [],
                    onAdd: onAdd,
                    onAwait: onAwait,
                    showsWish: false
                )
            }
            .accessibilityIdentifier("friend-book-add-menu")
        }
    }

    /// The book held: "✓ Chez vous", which still opens what is left to await.
    private var heldMenu: some View {
        Menu {
            BookAddMenuItems(
                formats: formats,
                owned: owned,
                awaitable: awaitable,
                onAdd: onAdd,
                wished: wished,
                onAwait: onAwait,
                onWish: onWish
            )
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

/// What a book the reader does not hold may become: onto the pile or among
/// the books read, in each format they may take it in; onto the wishlist; its
/// edition in the app's language awaited. The friend's book hero and the "…"
/// of an Actualités row open these same items.
struct BookAddMenuItems: View {
    let formats: [BookFormat]
    let owned: Bool
    let awaitable: [ReleaseFormat]
    let onAdd: (CopiedStatus, BookFormat) async -> Void
    var wished = false
    let onAwait: (ReleaseFormat) -> Void
    var onWish: () async -> Void = {}
    /// Off where the wish list is a button of its own beside the menu:
    /// Découvrir's large cards.
    var showsWish = true

    var body: some View {
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
        if !owned, showsWish {
            Section {
                Button("Liste d'envies", systemImage: wished ? "checkmark" : "bookmark") {
                    Task { await onWish() }
                }
                .disabled(wished)
                .accessibilityIdentifier("friend-book-wish")
            }
        }
        if !awaitable.isEmpty {
            Section {
                ForEach(awaitable) { format in
                    Button(
                        format.awaitLabel,
                        systemImage: format == .audiobook ? "headphones" : "binoculars"
                    ) {
                        onAwait(format)
                    }
                    .accessibilityIdentifier("friend-book-await-\(format.rawValue)")
                }
            }
        }
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
