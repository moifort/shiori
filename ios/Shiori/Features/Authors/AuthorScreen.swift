import SwiftUI

/// An author's page, connected: `AuthorViewModel` loads and acts on it, this
/// screen holds the menu, the sheets and the alerts, and `AuthorDetailPage`
/// draws it.
///
/// The first opening, by anyone, builds the author's shared catalogue on the
/// server, portrait included, which takes a few seconds; every later one reads it.
struct AuthorScreen: View {
    /// Opened as a sheet — from the Authors shelf, as a book opens from the
    /// library — rather than pushed: a close button in the corner.
    var isSheet = false

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AuthorViewModel
    @State private var selectedBook: Book?
    @State private var openAwaited: AwaitedEdition?
    @State private var openSeries: SeriesDestination?

    /// - Parameter isOffered: offered by Découvrir as an author a friend loves,
    ///   whom the reader may hold nothing of: the page is then built from `name`.
    init(key: String, name: String, isSheet: Bool = false, isOffered: Bool = false, client: AuthorsClient = .live) {
        self.isSheet = isSheet
        _viewModel = State(initialValue: AuthorViewModel(key: key, name: name, isOffered: isOffered, client: client))
    }

    var body: some View {
        AuthorDetailPage(
            name: viewModel.name,
            page: viewModel.page,
            releases: viewModel.releases,
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage,
            adding: viewModel.adding
        ) { action in
            switch action {
            case let .openBook(book): selectedBook = book
            case let .openSeries(destination): openSeries = destination
            case let .startSaga(saga, author, format): await viewModel.start(saga, author: author, format: format)
            case let .addWork(work, author, format): await viewModel.add(work, author: author, format: format)
            case let .openAwaited(edition): openAwaited = edition
            case let .stopAwaiting(edition): await viewModel.stopAwaiting(edition)
            case .refresh: await viewModel.load()
            }
        }
        .task { await viewModel.load() }
        .sheet(item: $selectedBook) { book in
            BookScreen(
                bookId: book.id,
                onChanged: { _ in Task { await viewModel.load() } },
                onDeleted: { _ in Task { await viewModel.load() } }
            )
        }
        .sheet(item: $openAwaited) { edition in
            NavigationStack {
                AwaitedEditionScreen(edition: edition) {
                    Task { await viewModel.stopAwaiting(edition) }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .shioriAwaitedEditionsDidChange)) { _ in
            Task { await viewModel.load() }
        }
        .navigationDestination(item: $openSeries) {
            SeriesScreen(seriesId: $0.seriesId, language: $0.language, proposal: $0.proposal)
        }
        // Back from a saga, read again: a volume added there moves the saga
        // among the reader's own, and a rating changes its row.
        .onChange(of: openSeries) { _, destination in
            if destination == nil { Task { await viewModel.load() } }
        }
        .toolbar {
            if isSheet {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) { dismiss() }
                }
            }
            if viewModel.page != nil {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Mettre à jour", systemImage: "arrow.clockwise") {
                            Task { await viewModel.refreshCatalogue() }
                        }
                        .accessibilityIdentifier("author-refresh")
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel(Text("Plus d'actions"))
                    .accessibilityIdentifier("author-menu")
                }
            }
        }
        .alert("Fiche non mise à jour", isPresented: $viewModel.refreshFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Shiori n'a rien trouvé de plus sur cet auteur. L'ancienne fiche est conservée ; réessayez plus tard.")
        }
        .overlay {
            if viewModel.isRefreshing {
                ZStack {
                    Color.black.opacity(0.1).ignoresSafeArea()
                    ProgressView("Mise à jour de la fiche…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .disabled(viewModel.isRefreshing)
        .alert(
            "Une erreur est survenue",
            isPresented: .init(
                get: { viewModel.errorMessage != nil && viewModel.page != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

#Preview {
    NavigationStack {
        AuthorScreen(key: "robin hobb", name: "Robin Hobb", client: .preview)
    }
}
