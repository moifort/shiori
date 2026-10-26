import SwiftUI

/// The Library tab's entry screen, connected — or a genre page, the same
/// screen narrowed to a genre and pushed from "Par genre". Owns the view
/// model, the search sheet and what a tap or a long press opens.
///
/// The entry screen roots the tab: what it opens is pushed over it on a phone
/// and set beside it on an unfolded iPhone Duo. A genre page lives on its
/// opener's stack and pushes on it.
struct LibraryShelvesScreen: View {
    var genre: BookGenre?
    /// A view another tab asked the Library to open, taken and cleared as soon
    /// as the entry screen shows it.
    var request: Binding<LibraryRequest?>?
    /// The same for the series: the home's "Séries en cours".
    var seriesRequest: Binding<SeriesRequest?>?
    var client: LibraryClient = .live

    @State private var viewModel: LibraryShelvesViewModel
    @State private var destination: LibraryDestination?
    @State private var showSearch = false
    @State private var quick: BookQuickRequest?

    init(
        genre: BookGenre? = nil,
        request: Binding<LibraryRequest?>? = nil,
        seriesRequest: Binding<SeriesRequest?>? = nil,
        client: LibraryClient = .live
    ) {
        self.genre = genre
        self.request = request
        self.seriesRequest = seriesRequest
        self.client = client
        _viewModel = State(initialValue: LibraryShelvesViewModel(client: client, genre: genre))
    }

    var body: some View {
        if genre == nil {
            DetailSplit(item: $destination) {
                page
            } detail: { opened in
                LibraryDestinationScreen(destination: opened, client: client)
            }
            .onChange(of: request?.wrappedValue, initial: true) { takeRequest() }
            .onChange(of: seriesRequest?.wrappedValue, initial: true) { takeSeriesRequest() }
        } else {
            page
                .searchesLibrary()
                .pushesDetail(item: $destination) { opened in
                    LibraryDestinationScreen(destination: opened, client: client)
                }
        }
    }

    private var page: some View {
        LibraryShelvesPage(
            shelves: viewModel.shelves,
            formats: viewModel.formats,
            selectedFormat: viewModel.view.format,
            genre: genre,
            subgenres: viewModel.subgenres,
            selectedSubgenre: viewModel.view.subgenre,
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage
        ) { action in
            switch action {
            case let .openBook(book): destination = .book(book)
            case let .openShelf(shelf): destination = .shelf(shelf, viewModel.view)
            case .openSeriesShelf: destination = .seriesShelf()
            case let .openSeries(series): destination = .series(series.seriesId)
            case .openAuthors: destination = .authors
            case let .openAuthor(author): destination = .author(AuthorDestination(author))
            case let .openGenre(genre): destination = .genre(genre)
            case let .selectFormat(format): Task { await viewModel.select(format: format) }
            case let .selectSubgenre(subgenre): Task { await viewModel.select(subgenre: subgenre) }
            case .search: showSearch = true
            case let .menu(book, action): quick = BookQuickRequest(book: book, action: action)
            case .refresh: Task { await viewModel.load() }
            }
        }
        .performsBookQuickActions($quick, client: client) { destination = $0 }
        .sheet(isPresented: $showSearch) { LibrarySearchScreen() }
        .task { await viewModel.loadOnAppear() }
        // A book added, finished, hearted or taken out: the rails are asked
        // again, in one request.
        .onReceive(NotificationCenter.default.publisher(for: .shioriDataDidChange)) { _ in
            Task { await viewModel.load() }
        }
    }

    private func takeSeriesRequest() {
        guard let seriesRequest, let asked = seriesRequest.wrappedValue else { return }
        seriesRequest.wrappedValue = nil
        destination = .seriesShelf(asked.state == .inProgress ? .inProgress : .all)
    }

    private func takeRequest() {
        guard let request, let asked = request.wrappedValue else { return }
        request.wrappedValue = nil
        // A book just added leads "Récemment": the entry screen shows it.
        destination = LibraryDestination(asked)
    }
}

#Preview {
    LibraryShelvesScreen(client: .preview)
}
