import SwiftUI

/// The wishlist, connected: owns the view model, opens an edition's page, and
/// asks what to do with a book wished for — put it on the pile, say it read,
/// or take it off the list.
struct WishlistScreen: View {
    var client: WishlistClient = .live

    @State private var viewModel: WishlistViewModel
    @State private var openedEdition: AwaitedEdition?
    @State private var chosen: Wish?

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
            case let .chooseWish(wish): chosen = wish
            case let .selectFormat(format): withAnimation(.smooth) { viewModel.format = format }
            case .refresh: Task { await viewModel.load() }
            }
        }
        .scrollAwayBar(String(localized: "Liste d'envies"))
        .confirmationDialog(
            chosen?.title ?? "",
            isPresented: Binding(get: { chosen != nil }, set: { if !$0 { chosen = nil } }),
            titleVisibility: .visible,
            presenting: chosen
        ) { wish in
            Button("À lire") { Task { await viewModel.add(wish, status: .toRead) } }
            Button("Déjà lu") { Task { await viewModel.add(wish, status: .read) } }
            Button("Retirer", role: .destructive) { Task { await viewModel.remove(wish) } }
        }
        .alert(
            "Action impossible",
            isPresented: Binding(get: { viewModel.actionError != nil }, set: { if !$0 { viewModel.actionError = nil } })
        ) {} message: {
            Text(viewModel.actionError ?? "")
        }
        .pushesDetail(item: $openedEdition) { edition in
            AwaitedEditionScreen(edition: edition) { Task { await viewModel.load() } }
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
