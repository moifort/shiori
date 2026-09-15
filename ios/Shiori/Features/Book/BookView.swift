import SwiftUI

/// One book's coordinator, presented as a sheet over the list that opened it:
/// owns the view model, the toolbar menu, the edit form, the rating prompt, the
/// delete confirmation, and the hop to the series screen.
///
/// The sheet carries its own NavigationStack, so the series screen pushes inside
/// it and closing the sheet always lands back on the row the reader tapped.
struct BookView: View {
    let bookId: String
    var onChanged: (Book) -> Void = { _ in }
    var onDeleted: (String) -> Void = { _ in }

    @State private var viewModel: BookViewModel
    @State private var showEditor = false
    @State private var showRatingPrompt = false
    @State private var confirmDelete = false
    @State private var openSeriesId: String?
    @Environment(\.dismiss) private var dismiss

    init(bookId: String, onChanged: @escaping (Book) -> Void = { _ in }, onDeleted: @escaping (String) -> Void = { _ in }) {
        self.bookId = bookId
        self.onChanged = onChanged
        self.onDeleted = onDeleted
        _viewModel = State(wrappedValue: BookViewModel(bookId: bookId))
    }

    var body: some View {
        NavigationStack {
            Group {
                if let book = viewModel.book {
                    BookPage(
                        book: book,
                        otherVolumes: viewModel.otherVolumes,
                        seriesName: book.series?.name,
                        isSaving: viewModel.isSaving,
                        onSetStatus: { status in run { await viewModel.setStatus(status) } },
                        onRate: { showRatingPrompt = true },
                        onToggleHidden: { run { await viewModel.setHidden(!book.hidden) } },
                        onOpenSeries: { openSeriesId = book.series?.id },
                        onAddVolume: { volume in
                            Task {
                                _ = await viewModel.addVolume(volume)
                                await viewModel.load()
                            }
                        }
                    )
                } else if viewModel.isLoading {
                    LoadingStateView()
                } else {
                    ContentUnavailableView {
                        Label("Livre introuvable", systemImage: "book.closed")
                    } description: {
                        Text(viewModel.errorMessage ?? "Ce livre n'est plus dans votre bibliothèque.")
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            // Toolbar actions close their menu before the mutation leaves, so the
            // call is made visible by a scrim rather than by the control itself.
            .overlay {
                if viewModel.isSaving {
                    ZStack {
                        Color.black.opacity(0.1).ignoresSafeArea()
                        ProgressView()
                    }
                }
            }
            .sheet(isPresented: $showEditor) {
                if let book = viewModel.book {
                    BookEditView(book: book) { correction, rating in
                        let saved = await viewModel.save(correction, rating: rating)
                        if let book = viewModel.book { onChanged(book) }
                        guard !saved else { return nil }
                        // The form shows the failure itself: an alert hung on this
                        // screen would stay hidden behind the form's sheet.
                        defer { viewModel.dismissError() }
                        return viewModel.errorMessage ?? String(localized: "Une erreur est survenue")
                    }
                }
            }
            .sheet(isPresented: $showRatingPrompt) {
                RatingPromptView { stars in
                    showRatingPrompt = false
                    run { await viewModel.rate(stars) }
                }
            }
            .navigationDestination(item: $openSeriesId) { id in
                SeriesView(seriesId: id)
            }
            .alert(
                "Une erreur est survenue",
                isPresented: .init(
                    get: { viewModel.errorMessage != nil && viewModel.book != nil },
                    set: { if !$0 { viewModel.dismissError() } }
                )
            ) {
                Button("OK", role: .cancel) { viewModel.dismissError() }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .task { await viewModel.load() }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) { dismiss() }
        }
        if let book = viewModel.book {
            ToolbarItem(placement: .primaryAction) {
                menu(for: book)
            }
        }
    }

    private func menu(for book: Book) -> some View {
        Menu {
            // Status and sharing are switched on the page itself, and the series
            // opens from its row: the menu only holds what the page cannot do.
            Button("Modifier", systemImage: "pencil") {
                showEditor = true
            }
            .accessibilityIdentifier("book-edit")

            Button("Retirer de ma bibliothèque", systemImage: "trash", role: .destructive) {
                confirmDelete = true
            }
            .accessibilityIdentifier("book-delete")
        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel(Text("Plus d'actions"))
        .accessibilityIdentifier("book-detail-menu")
        // Attached to the menu, as in Vinarium: a dialog hung on the sheet's root
        // would anchor to the whole screen instead of the button that asked.
        .confirmationDialog(
            "Retirer ce livre de votre bibliothèque ?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Retirer", role: .destructive) {
                Task {
                    if await viewModel.delete() {
                        onDeleted(bookId)
                        dismiss()
                    }
                }
            }
            .accessibilityIdentifier("choice-delete")
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Votre note sera perdue. Cette action est définitive.")
        }
    }

    /// Runs a mutation and tells the list what the server answered, so the row
    /// behind this screen matches it without refetching the whole library.
    private func run(_ operation: @escaping () async -> Void) {
        Task {
            await operation()
            if let book = viewModel.book { onChanged(book) }
        }
    }
}
