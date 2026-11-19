import SwiftUI

/// The first buttons of a friend's book hero, where the reader's own book has
/// its next step: "+ Ajouter", onto the pile, or among the books read, in print or as a
/// recording, or onto the wish list — a reader who never listens takes a friend's recording as a
/// book, and a printed book is offered heard once Audible confirms it sells
/// it. Its edition in the app's language, translated or recorded, may be
/// awaited from here too, one action at a time. Once the reader holds the book
/// it says so, "✓ Ajouté" on glass, and still opens what is left to await.
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
    /// What may be awaited and what is: an edition awaited is the action the
    /// "+ Ajouter" says.
    var watch: EditionWatch? = nil
    /// The capsule of an edition awaited pressed: it is given up.
    var onStopAwaiting: (ReleaseFormat) -> Void = { _ in }

    var body: some View {
        if owned {
            heldMenu
        } else {
            // The one button every book page shares: "+ Ajouter", whose menu
            // holds the wish list and the editions to await, and which says
            // the one action chosen; a second tap takes it back.
            AddMenuButton(
                size: .page,
                done: done,
                isDisabled: formats.isEmpty && awaitable.isEmpty,
                onUndo: undo
            ) {
                BookAddMenuItems(
                    formats: formats,
                    owned: false,
                    awaitable: awaitable,
                    onAdd: onAdd,
                    onAwait: onAwait,
                    onWish: onWish
                )
            }
            .accessibilityIdentifier("friend-book-add-menu")
        }
    }

    /// What the reader made of the book from here: on the wish list, or an
    /// edition awaited.
    private var done: TakenState? {
        if wished { return .wished }
        if let format = watch?.offered.first(where: { watch?.awaited.contains($0) == true }) {
            return .awaited(format)
        }
        return nil
    }

    private func undo() {
        if wished {
            Task { await onWish() }
        } else if case let .awaited(format) = done {
            onStopAwaiting(format)
        }
    }

    /// The book held: "✓ Ajouté" on glass, as Actualité's cards say it,
    /// which still opens the editions left to await, and takes no tap once
    /// none is.
    @ViewBuilder
    private var heldMenu: some View {
        if awaitable.isEmpty {
            OwnedCapsule(size: .page)
        } else {
            OwnedCapsule(size: .page) {
                BookAddMenuItems(
                    formats: formats,
                    owned: owned,
                    awaitable: awaitable,
                    onAdd: onAdd,
                    wished: wished,
                    onAwait: onAwait,
                    onWish: onWish
                )
            }
            .accessibilityIdentifier("friend-book-add-menu")
        }
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
                Button("Ajouter à la liste d'envies", systemImage: wished ? "checkmark" : "bookmark") {
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
