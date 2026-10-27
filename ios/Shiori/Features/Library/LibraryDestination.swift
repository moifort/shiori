import SwiftUI

/// What the Library tab pushes: a book, one of its shelves, the series, the
/// authors, the narrators, a genre page. Each pushed screen pushes the next one on its own.
enum LibraryDestination: Identifiable, Hashable {
    case book(Book)
    /// The formats are the opener's pills, offered again over the shelf.
    case shelf(BookShelf, ShelvesView = ShelvesView(), status: ReadingStatus? = nil, formats: [BookFormat] = [])
    /// "Toute la pile", opened from the bottom of the pile.
    case wholePile(ShelvesView)
    case seriesShelf(SeriesShelfFilter = .all)
    case setAsideSeries
    case series(String)
    case authors
    case author(AuthorDestination)
    case narrators
    case narrator(NarratorDestination)
    case genre(BookGenre)

    var id: String {
        switch self {
        case let .book(book): "book-\(book.id)"
        case let .shelf(shelf, view, status, _): "shelf-\(shelf.rawValue)-\(view.cacheKey)-\(status?.rawValue ?? "")"
        case let .wholePile(view): "whole-pile-\(view.cacheKey)"
        case let .seriesShelf(filter): "series-shelf-\(filter.rawValue)"
        case .setAsideSeries: "series-set-aside"
        case let .series(id): "series-\(id)"
        case .authors: "authors"
        case let .author(author): "author-\(author.key)"
        case .narrators: "narrators"
        case let .narrator(narrator): "narrator-\(narrator.key)"
        case let .genre(genre): "genre-\(genre.rawValue)"
        }
    }

    /// A view another tab asked for, as the destination it opens: the pile,
    /// the books read or being read, the favourites.
    init?(_ request: LibraryRequest) {
        switch request.filter {
        case .status(.toRead): self = .shelf(.toRead)
        case .status(.read): self = .shelf(.read)
        case .status(.reading): self = .shelf(.recent, status: .reading)
        case .status(.dropped): self = .shelf(.dropped)
        case .favorites: self = .shelf(.loved)
        case nil: return nil
        }
    }
}

/// The screen a destination opens.
struct LibraryDestinationScreen: View {
    let destination: LibraryDestination
    var client: LibraryClient = .live

    var body: some View {
        switch destination {
        case let .book(book):
            BookScreen(bookId: book.id)
        case let .shelf(.all, view, _, formats):
            BookMosaicScreen(view: view, formats: formats, client: client)
        case let .shelf(.toRead, view, _, _):
            PileScreen(view: view, client: client)
        case let .wholePile(view):
            WholePileScreen(view: view, client: client)
        case let .shelf(shelf, view, status, formats):
            BookShelfScreen(shelf: shelf, view: view, status: status, formats: formats, client: client)
        case let .seriesShelf(filter):
            SeriesShelfScreen(filter: filter)
        case .setAsideSeries:
            SetAsideSeriesScreen()
        case let .series(id):
            SeriesScreen(seriesId: id)
        case .authors:
            AuthorShelfScreen()
        case let .author(author):
            AuthorScreen(key: author.key, name: author.name)
        case .narrators:
            NarratorShelfScreen(library: client)
        case let .narrator(narrator):
            NarratorScreen(key: narrator.key, name: narrator.name)
        case let .genre(genre):
            LibraryShelvesScreen(genre: genre, client: client)
        }
    }
}

/// A long press's choice, waiting to be carried out by the screen.
struct BookQuickRequest: Identifiable, Equatable {
    let book: Book
    let action: BookQuickAction
    var id: String { "\(book.id)-\(action)" }
}

extension View {
    /// Carries out what a long press on a cover asked: a status, a heart and
    /// stars are written at once — finishing a book asks for its stars first,
    /// as the home does —, a series or an author is opened, and taking the
    /// book out is confirmed. Every write posts the change notice the shelves
    /// listen to.
    func performsBookQuickActions(
        _ request: Binding<BookQuickRequest?>,
        client: LibraryClient,
        open: @escaping (LibraryDestination) -> Void
    ) -> some View {
        modifier(BookQuickActions(request: request, client: client, open: open))
    }
}

private struct BookQuickActions: ViewModifier {
    @Binding var request: BookQuickRequest?
    let client: LibraryClient
    let open: (LibraryDestination) -> Void

    @State private var finishing: Book?
    @State private var rating: Book?
    @State private var removing: Book?

    func body(content: Content) -> some View {
        content
            .onChange(of: request) { _, request in
                guard let request else { return }
                self.request = nil
                perform(request)
            }
            .sheet(item: $finishing) { book in
                FinishedBookSheet(book: book) { stars in
                    finishing = nil
                    write {
                        _ = try await client.setStatus(book.id, .read)
                        if let stars { _ = try await client.rate(book.id, stars) }
                    }
                } onCancel: {
                    finishing = nil
                }
                .presentationDetents([.medium])
            }
            .sheet(item: $rating) { book in
                RatingPromptSheet(current: book.rating) { stars in
                    write { _ = try await client.rate(book.id, stars) }
                }
                .presentationDetents([.medium])
            }
            .confirmationDialog(
                "Supprimer ce livre ?",
                isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
                titleVisibility: .visible,
                presenting: removing
            ) { book in
                Button("Supprimer", role: .destructive) {
                    write { try await client.delete(book.id) }
                }
            } message: { _ in
                Text("Sa note et ses commentaires partent avec lui.")
            }
    }

    private func perform(_ request: BookQuickRequest) {
        let book = request.book
        switch request.action {
        case .setStatus(.read): finishing = book
        case let .setStatus(status): write { _ = try await client.setStatus(book.id, status) }
        case .toggleFavorite: write { _ = try await client.setFavorite(book.id, !book.favorite) }
        case .rate: rating = book
        case let .openSeries(id): open(.series(id))
        case let .openAuthor(key, name): open(.author(AuthorDestination(key: key, name: name)))
        case .remove: removing = book
        }
    }

    private func write(_ work: @escaping @MainActor () async throws -> Void) {
        Task { @MainActor in
            do { try await work() } catch {
                guard !isCancellation(error) else { return }
                _ = reportError(error)
            }
        }
    }
}
