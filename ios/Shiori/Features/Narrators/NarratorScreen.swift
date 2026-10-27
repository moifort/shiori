import SwiftUI

/// A narrator's page, connected: `NarratorViewModel` loads and acts on it, this
/// screen holds the bar and the pushes, and `NarratorDetailPage` draws it.
///
/// The first opening, by anyone, has the AI describe the narrator on the
/// server, portrait included, which takes a few seconds: the reader's
/// recordings are drawn first, and the pill says the AI is at work.
struct NarratorScreen: View {
    @Environment(\.dismiss) private var dismissPresentation
    @Environment(\.detailClosing) private var closing
    @State private var viewModel: NarratorViewModel
    @State private var selectedBook: Book?
    @State private var openSeries: SeriesDestination?
    @State private var destination: LibraryDestination?
    @State private var quick: BookQuickRequest?
    /// The form correcting the narrator's facts and biography.
    @State private var isEditing = false
    /// The sheet giving the narrator another face.
    @State private var isPickingPortrait = false
    private let library: LibraryClient

    init(
        key: String,
        name: String,
        client: NarratorsClient = .live,
        library: LibraryClient = .live
    ) {
        self.library = library
        _viewModel = State(initialValue: NarratorViewModel(key: key, name: name, client: client))
    }

    var body: some View {
        NarratorDetailPage(
            name: viewModel.name,
            page: viewModel.page,
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage
        ) { action in
            switch action {
            case let .openBook(book): selectedBook = book
            case let .openSeries(destination): openSeries = destination
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
        .pushesDetail(item: $destination) { LibraryDestinationScreen(destination: $0, client: library) }
        .performsBookQuickActions($quick, client: library) { destination = $0 }
        .navigationDestination(item: $openSeries) {
            SeriesScreen(seriesId: $0.seriesId, proposal: $0.proposal)
                .closesAsPushed()
        }
        // Back from a saga, read again: a rating there changes its card.
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
                    .accessibilityIdentifier("narrator-favorite")
                }
                // Only a narrator the reader holds a recording of: the server
                // corrects no one else.
                if page.bookCount > 0 {
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
                initials: viewModel.page?.initials ?? "",
                choices: viewModel.portraitChoices,
                loadFailed: viewModel.portraitChoicesFailed
            ) { choice in
                await viewModel.correct(PersonCorrection(portraitURL: choice.url))
            }
            .task { await viewModel.loadPortraitChoices() }
        }
        // The AI at work, said by a pill floating over the page.
        .generatingPill(viewModel.isCataloguing)
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
        NarratorScreen(key: "bernard-gabay", name: "Bernard Gabay", client: .preview)
    }
}
