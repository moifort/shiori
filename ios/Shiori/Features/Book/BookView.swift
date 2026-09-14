import SwiftUI

/// One book's coordinator, presented as a sheet over the list that opened it:
/// owns the view model, the toolbar actions, the note sheet, the delete
/// confirmation, and the hop to the series screen.
///
/// The sheet carries its own NavigationStack, so the series screen pushes inside
/// it and closing the sheet always lands back on the row the reader tapped.
struct BookView: View {
    let bookId: String
    var onChanged: (Book) -> Void = { _ in }
    var onDeleted: (String) -> Void = { _ in }

    @State private var viewModel: BookViewModel
    @State private var showNoteEditor = false
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
                        onRate: { stars in run { await viewModel.rate(stars) } },
                        onEditNote: { showNoteEditor = true },
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
            .sheet(isPresented: $showNoteEditor) {
                NoteEditorView(
                    note: viewModel.book?.note ?? "",
                    onSave: { note in
                        showNoteEditor = false
                        run { await viewModel.setNote(note) }
                    },
                    onCancel: { showNoteEditor = false }
                )
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
            ToolbarItemGroup {
                // The one step that moves a book forward, one tap from the top. A
                // read book has no next step: rating it is done from the page.
                switch book.status {
                case .toRead:
                    ToolbarIconButton(title: "Commencer la lecture", systemImage: "book") {
                        run { await viewModel.setStatus(.reading) }
                    }
                    .accessibilityIdentifier("book-start-reading")
                case .reading:
                    ToolbarIconButton(title: "Marquer comme lu", systemImage: "checkmark") {
                        run { await viewModel.setStatus(.read) }
                    }
                    .accessibilityIdentifier("book-mark-read")
                case .read:
                    EmptyView()
                }

                menu(for: book)
            }
        }
    }

    private func menu(for book: Book) -> some View {
        Menu {
            Button(
                book.note?.isEmpty == false ? "Modifier le commentaire" : "Écrire un commentaire",
                systemImage: "square.and.pencil"
            ) {
                showNoteEditor = true
            }

            Section {
                if book.series != nil {
                    Button("Voir la série", systemImage: "square.stack") {
                        openSeriesId = book.series?.id
                    }
                    .accessibilityIdentifier("menu-series-button")
                }
                Button(
                    book.hidden ? "Partager ce livre" : "Ne pas partager",
                    systemImage: book.hidden ? "eye" : "eye.slash"
                ) {
                    run { await viewModel.setHidden(!book.hidden) }
                }
                .accessibilityIdentifier("menu-hidden-button")
            }

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
            Text("Votre note et votre commentaire seront perdus. Cette action est définitive.")
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
