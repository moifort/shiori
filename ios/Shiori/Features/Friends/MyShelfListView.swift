import SwiftUI

/// One list of the reader's own shelf, as a box of the Partagé tab opens it.
///
/// The favourites list the hearted sagas first and then the hearted books a
/// saga does not already stand for, and carry the share button: the whole list
/// as text, for a mail, a message, or the clipboard. A row opens the book on
/// its own page, where it can be changed like anywhere else in the library.
struct MyShelfListView: View {
    let list: MyShelfList
    let shelf: FriendProfile

    @State private var openBook: Book?

    var body: some View {
        List {
            switch list {
            case .favorites:
                favorites
            case .pile:
                books(shelf.pile, empty: "Votre pile est vide.")
            case .reading:
                books(shelf.reading, empty: "Aucune lecture en cours.", showsSeries: true)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if list == .favorites, !isEmptyFavorites {
                ToolbarItem(placement: .primaryAction) {
                    // Copy has its own entry: the system sheet does not always
                    // offer it for plain text, and it is the one way to paste
                    // the list somewhere no share extension reaches.
                    Menu {
                        ShareLink(
                            item: favoritesText,
                            subject: Text("Mes favoris"),
                            preview: SharePreview(Text("Mes favoris"))
                        ) {
                            Label("Envoyer…", systemImage: "paperplane")
                        }
                        Button {
                            UIPasteboard.general.string = favoritesText
                        } label: {
                            Label("Copier la liste", systemImage: "doc.on.doc")
                        }
                        .accessibilityIdentifier("my-shelf-copy-favorites")
                    } label: {
                        Label("Partager mes favoris", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("my-shelf-share-favorites")
                }
            }
        }
        .sheet(item: $openBook) { book in
            BookView(bookId: book.id)
        }
    }

    private var title: LocalizedStringKey {
        switch list {
        case .favorites: "Mes favoris"
        case .pile: "Ma pile"
        case .reading: "En cours"
        }
    }

    private var favoritesText: String {
        FavoritesSharing.text(sagas: shelf.favoriteSagas, books: shelf.favorites.map(\.book))
    }

    private var isEmptyFavorites: Bool {
        shelf.favoriteSagas.isEmpty && shelf.favorites.isEmpty
    }

    @ViewBuilder
    private var favorites: some View {
        if isEmptyFavorites {
            Text("Aucun favori pour l'instant. Un cœur sur un livre ou une série le fait apparaître ici.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            if !shelf.favoriteSagas.isEmpty {
                Section("Séries") {
                    ForEach(shelf.favoriteSagas) { saga in
                        SagaRow(saga: saga, showsCover: true)
                    }
                }
            }
            if !shelf.favorites.isEmpty {
                books(shelf.favorites, title: "Livres", empty: "", showsStatus: true)
            }
        }
    }

    @ViewBuilder
    private func books(
        _ entries: [FriendBook],
        title: LocalizedStringKey? = nil,
        empty: LocalizedStringKey,
        showsStatus: Bool = false,
        showsSeries: Bool = false
    ) -> some View {
        Section {
            if entries.isEmpty {
                Text(empty).font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(entries) { entry in
                    let book = entry.book
                    BookRow(
                        title: book.title,
                        authorLine: book.authorLine,
                        cover: book,
                        status: book.status,
                        rating: book.rating,
                        series: showsSeries ? book.series : nil,
                        statusTag: showsStatus ? book.status : nil,
                        genre: book.genre,
                        subgenre: book.subgenres.first,
                        language: book.language,
                        isFavorite: book.favorite
                    )
                    .contentShape(.rect)
                    .onTapGesture { openBook = book }
                    .accessibilityIdentifier("my-shelf-book-row")
                }
            }
        } header: {
            if let title { Text(title) }
        }
    }
}

/// A saga on somebody's shelf: its name, author and genre. Among the
/// favourites it is drawn like a book, with the cover of its first volume;
/// elsewhere it says how many of its volumes are on that shelf — never how
/// many the saga has, since the catalogue is not something a friendship opens.
struct SagaRow: View {
    let saga: FriendSaga
    /// The favourites draw the cover in place of the volume count.
    var showsCover = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if showsCover {
                BookCover(book: coverBook, showsFormatBadge: false)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(saga.name).font(.body.weight(.medium))
                    if saga.favorite {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(.pink)
                            .accessibilityLabel(Text("Favori"))
                    }
                    if let language = saga.language, language.isForeign {
                        LanguageTag(language: language)
                    }
                }
                if let author = saga.author {
                    Text(author).font(.subheadline).foregroundStyle(.secondary)
                }
                if let genre = saga.genre {
                    Text([genre.label, saga.subgenre].compactMap(\.self).joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if !showsCover {
                Label("\(saga.ownedCount) tome(s)", systemImage: "books.vertical")
                    .labelStyle(.caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 2)
    }

    /// The saga as the cover view draws it: its first volume's cover, or the
    /// typographic placeholder made from its name and author.
    private var coverBook: Book {
        Book(
            id: saga.id,
            title: saga.name,
            authors: saga.author.map { [$0] } ?? [],
            coverURL: saga.coverURL,
            status: .read
        )
    }
}
