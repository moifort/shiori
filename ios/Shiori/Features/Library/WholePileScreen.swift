import SwiftUI

/// "Toute la pile", connected: owns its view model, pushes the books it
/// opens, and carries out the long press.
struct WholePileScreen: View {
    var client: LibraryClient = .live

    @State private var viewModel: WholePileViewModel
    @State private var destination: LibraryDestination?
    @State private var quick: BookQuickRequest?

    init(view: ShelvesView = ShelvesView(), client: LibraryClient = .live) {
        self.client = client
        _viewModel = State(initialValue: WholePileViewModel(client: client, view: view))
    }

    var body: some View {
        WholePilePage(
            sections: viewModel.sections,
            grouping: viewModel.grouping,
            label: viewModel.label,
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

    private func handle(_ action: WholePileAction) {
        switch action {
        case let .openBook(book): destination = .book(book)
        case let .selectGrouping(grouping): viewModel.select(grouping: grouping)
        case let .menu(book, action): quick = BookQuickRequest(book: book, action: action)
        case .refresh: Task { await viewModel.load() }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        WholePileScreen(client: .preview)
    }
}
#endif
