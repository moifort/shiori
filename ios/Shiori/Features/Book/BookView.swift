import SwiftUI

/// One book's coordinator: owns the view model, the note sheet, the delete
/// confirmation, and the hop to the series screen.
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
                    },
                    onDelete: { confirmDelete = true }
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
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Votre note et votre commentaire seront perdus. Cette action est définitive.")
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
        .task { await viewModel.load() }
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
