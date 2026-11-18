import SwiftUI

/// The wishlist, connected: owns the view model, opens an edition's page, and
/// asks what to do with a book wished for — put it on the pile, say it read,
/// or take it off the list.
struct WishlistScreen: View {
    var client: WishlistClient = .live

    @State private var viewModel: WishlistViewModel
    @State private var openedEdition: AwaitedEdition?
    @State private var openedWish: Wish?

    init(client: WishlistClient = .live) {
        self.client = client
        _viewModel = State(initialValue: WishlistViewModel(client: client))
    }

    var body: some View {
        WishlistPage(
            wishlist: viewModel.shown,
            formats: viewModel.formats,
            selectedFormat: viewModel.format,
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage
        ) { action in
            switch action {
            case let .openEdition(edition): openedEdition = edition
            case let .openWish(wish): openedWish = wish
            case let .dropWish(wish): Task { await viewModel.remove(wish) }
            case let .dropEdition(edition): Task { await viewModel.stopAwaiting(edition) }
            case let .selectFormat(format): withAnimation(.smooth) { viewModel.format = format }
            case .refresh: Task { await viewModel.load() }
            }
        }
        .scrollAwayBar(String(localized: "Liste d'envies"))
        .alert(
            "Action impossible",
            isPresented: Binding(get: { viewModel.actionError != nil }, set: { if !$0 { viewModel.actionError = nil } })
        ) {} message: {
            Text(viewModel.actionError ?? "")
        }
        // A book wished for opens its own page, as from the pile.
        .pushesDetail(item: $openedWish) { WishScreen(wish: $0) }
        .pushesDetail(item: $openedEdition) { edition in
            AwaitedEditionScreen(edition: edition)
        }
        .task { await viewModel.loadOnAppear() }
        .onReceive(NotificationCenter.default.publisher(for: .shioriWishlistDidChange)) { _ in
            Task { await viewModel.load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .shioriAwaitedEditionsDidChange)) { _ in
            Task { await viewModel.load() }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack { WishlistScreen(client: .preview) }
}
#endif
