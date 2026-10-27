import SwiftUI

/// An author's page, connected: `AuthorViewModel` loads and acts on it, this
/// screen holds the bar, the sheets and the alerts, and `AuthorDetailPage`
/// draws it.
///
/// The first opening, by anyone, builds the author's shared catalogue on the
/// server, portrait included, which takes a few seconds: the reader's books are
/// drawn first, and the bar says the AI is at work. Every later opening reads it.
struct AuthorScreen: View {
    @Environment(\.dismiss) private var dismissPresentation
    @Environment(\.detailClosing) private var closing
    @State private var viewModel: AuthorViewModel
    @State private var selectedBook: Book?
    @State private var openSeries: SeriesDestination?
    @State private var openWork: AuthorWork?
    @State private var destination: LibraryDestination?
    @State private var quick: BookQuickRequest?
    /// The form correcting the author's facts and biography.
    @State private var isEditing = false
    /// The sheet giving the author another face.
    @State private var isPickingPortrait = false
    private let library: LibraryClient

    /// - Parameter isOffered: offered by Découvrir as an author a friend loves,
    ///   whom the reader may hold nothing of: the page is then built from `name`.
    init(
        key: String,
        name: String,
        isOffered: Bool = false,
        client: AuthorsClient = .live,
        library: LibraryClient = .live
    ) {
        self.library = library
        _viewModel = State(initialValue: AuthorViewModel(key: key, name: name, isOffered: isOffered, client: client))
    }

    var body: some View {
        AuthorDetailPage(
            name: viewModel.name,
            page: viewModel.page,
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage
        ) { action in
            switch action {
            case let .openBook(book): selectedBook = book
            case let .openSeries(destination): openSeries = destination
            case let .openWork(work): openWork = work
            case let .menu(book, action): quick = BookQuickRequest(book: book, action: action)
            case .refresh: await viewModel.load()
            }
        }
        .task {
            await viewModel.load()
            await viewModel.buildCatalogueIfAwaiting()
        }
        .pushesDetail(item: $selectedBook) { book in
            BookScreen(
                bookId: book.id,
                onChanged: { _ in Task { await viewModel.load() } },
                onDeleted: { _ in Task { await viewModel.load() } }
            )
        }
        .pushesDetail(item: $openWork) { work in
            AuthorWorkPage(
                work: work,
                author: viewModel.page?.author.name ?? viewModel.name,
                isAdding: viewModel.adding == work.id
            ) {
                await viewModel.add(work, author: viewModel.page?.author.name ?? viewModel.name, format: .print)
                openWork = nil
            }
        }
        .pushesDetail(item: $destination) { LibraryDestinationScreen(destination: $0, client: library) }
        .performsBookQuickActions($quick, client: library) { destination = $0 }
        .onReceive(NotificationCenter.default.publisher(for: .shioriAwaitedEditionsDidChange)) { _ in
            Task { await viewModel.load() }
        }
        .navigationDestination(item: $openSeries) {
            SeriesScreen(seriesId: $0.seriesId, proposal: $0.proposal)
                .closesAsPushed()
        }
        // Back from a saga, read again: a volume added there moves the saga
        // among the reader's own, and a rating changes its row.
        .onChange(of: openSeries) { _, destination in
            if destination == nil { Task { await viewModel.load() } }
        }
        .toolbar {
            if closing.showsCloseButton {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) {
                        closing.close(dismissPresentation)
                    }
                }
            }
            if let page = viewModel.page {
                ToolbarItem(placement: .primaryAction) {
                    AsyncToolbarButton(
                        title: viewModel.isFavorite ? "Retirer des préférés" : "Préféré",
                        systemImage: viewModel.isFavorite ? "heart.fill" : "heart"
                    ) {
                        await viewModel.toggleFavorite()
                    }
                    .accessibilityIdentifier("author-favorite")
                }
                // Only an author the reader holds a book of: the server corrects
                // no one else.
                if page.author.bookCount > 0 {
                    ToolbarItem(placement: .primaryAction) {
                        PersonActionsMenu { action in
                            switch action {
                            case .edit: isEditing = true
                            case .portrait: isPickingPortrait = true
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            if let page = viewModel.page {
                PersonEditSheet(facts: page.facts) { correction in
                    await viewModel.correct(correction)
                }
            }
        }
        .sheet(isPresented: $isPickingPortrait) {
            PortraitPickerSheet(
                initials: viewModel.page?.author.initials ?? "",
                choices: viewModel.portraitChoices,
                loadFailed: viewModel.portraitChoicesFailed
            ) { choice in
                await viewModel.correct(PersonCorrection(portraitURL: choice.url))
            }
            .task { await viewModel.loadPortraitChoices() }
        }
        // The AI at work, said by a pill floating over the page: the page
        // under it stays readable and every action at hand.
        .generatingPill(viewModel.isGenerating)
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
