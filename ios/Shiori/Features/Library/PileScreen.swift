import SwiftUI

/// "Pile à lire", connected: owns its view model, pushes the books and the
/// whole pile it opens, and carries out the long press.
struct PileScreen: View {
    var client: LibraryClient = .live

    @State private var viewModel: PileViewModel
    @State private var destination: LibraryDestination?
    @State private var quick: BookQuickRequest?

    init(view: ShelvesView = ShelvesView(), client: LibraryClient = .live) {
        self.client = client
        _viewModel = State(initialValue: PileViewModel(client: client, view: view))
    }

    var body: some View {
        PilePage(
            pile: viewModel.pile,
            formats: viewModel.shownFormats,
            selectedFormat: viewModel.view.format,
            genres: viewModel.shownGenres,
            selectedGenre: viewModel.view.genre,
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage,
            onAction: handle
        )
        .pushesDetail(item: $destination) { LibraryDestinationScreen(destination: $0, client: client) }
        .performsBookQuickActions($quick, client: client) { destination = $0 }
        .task { await viewModel.loadOnAppear() }
        .onReceive(NotificationCenter.default.publisher(for: .shioriDataDidChange)) { _ in
            Task { await viewModel.load() }
        }
    }

    private func handle(_ action: PileAction) {
        switch action {
        case let .openBook(book): destination = .book(book)
        case let .selectFormat(format): Task { await viewModel.select(format: format) }
        case let .selectGenre(genre): Task { await viewModel.select(genre: genre) }
        case let .menu(book, action): quick = BookQuickRequest(book: book, action: action)
        case .openWholePile: destination = .wholePile(viewModel.view)
        case .refresh: Task { await viewModel.load() }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        PileScreen(client: .preview)
    }
}
#endif
