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
                        SagaRow(saga: saga, showsCovers: true)
                    }
                }
            }
            if !shelf.favorites.isEmpty {
                books(shelf.favorites, title: "Livres", empty: "", asFavorites: true)
            }
        }
    }

    @ViewBuilder
    private func books(
        _ entries: [FriendBook],
        title: LocalizedStringKey? = nil,
        empty: LocalizedStringKey,
        // Every favourite is hearted and nearly all are read: the heart and
        // the status would say the same thing on every row, so the genre
        // takes their corner.
        asFavorites: Bool = false,
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
                        rating: asFavorites ? nil : book.rating,
                        series: showsSeries ? book.series : nil,
                        genre: book.genre,
                        // The favourites keep to the genre in the corner.
                        subgenre: asFavorites ? nil : book.subgenres.first,
                        language: book.language,
                        isFavorite: asFavorites ? false : book.favorite,
                        genreInCorner: asFavorites
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
/// favourites it is drawn as the Series tab draws it, its volumes on the shelf
/// as a strip of covers underneath — owned volumes only, since the catalogue
/// is not something a friendship opens — with its genre, alone, in the top
/// corner.
/// Elsewhere it says it is hearted and how many of its volumes are on that
/// shelf.
struct SagaRow: View {
    let saga: FriendSaga
    /// The favourites draw the covers in place of the volume count.
    var showsCovers = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                // The marks in the top corner, as on a book row: the heart is
                // left out among the favourites, where every saga has one, and
                // the genre takes its place.
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(saga.name).font(.body.weight(.medium)).lineLimit(2)
                    Spacer(minLength: 0)
                    HStack(spacing: 6) {
                        if let language = saga.language, language.isForeign {
                            LanguageTag(language: language)
                        }
                        if showsCovers {
                            if let genre = saga.genre {
                                RowChip(text: genre.label, tint: genre.tint)
                            }
                        } else {
                            if saga.favorite {
                                Image(systemName: "heart.fill")
                                    .foregroundStyle(.pink)
                                    .accessibilityLabel(Text("Favori"))
                            }
                            Label("\(saga.ownedCount) tome(s)", systemImage: "books.vertical")
                                .labelStyle(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption2)
                    .fixedSize()
                }
                if let author = saga.author {
                    Text(author).font(.subheadline).foregroundStyle(.secondary)
                }
                if !showsCovers, let genre = saga.genre {
                    Text([genre.label, saga.subgenre].compactMap(\.self).joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            // Covers only: where the reader stands on each volume is theirs
            // to read on the saga itself, not on a list of what they love.
            if showsCovers, !saga.volumes.isEmpty {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 10) {
                        ForEach(saga.volumes) { volume in
                            BookCover(book: volume, width: 44, showsFormatBadge: false)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 2)
    }
}

extension FriendSaga {
    /// The saga as one cover: its first volume on the shelf, or the typographic
    /// placeholder made from its name and author.
    var coverBook: Book {
        volumes.first ?? Book(id: id, title: name, authors: author.map { [$0] } ?? [], status: .read)
    }
}
