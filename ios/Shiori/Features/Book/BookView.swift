import SwiftUI

/// One book's coordinator, presented as a sheet over the list that opened it:
/// owns the view model, the toolbar menu, the edit form, the rating prompt, the
/// delete confirmation, filing a standalone book into a saga, and the hop to
/// the series screen.
///
/// The sheet carries its own NavigationStack, so the series screen pushes inside
/// it and closing the sheet always lands back on the row the reader tapped.
struct BookView: View {
    let bookId: String
    var onChanged: (Book) -> Void = { _ in }
    var onDeleted: (String) -> Void = { _ in }

    @State private var viewModel: BookViewModel
    @State private var showEditor = false
    @State private var showGenreEditor = false
    @State private var showSeriesJoin = false
    @State private var showRecommendation = false
    @State private var showNote = false
    @State private var showRatingPrompt = false
    @State private var editedField: BookField?
    @State private var confirmDelete = false
    @State private var openSeries: SeriesDestination?
    /// What the page offers to await in the app's language, and what it awaits.
    @State private var offer = EditionOffer()
    /// The awaits sent and not answered yet, by format: the page already shows
    /// them, so giving one up waits for the server's id.
    @State private var awaiting: [ReleaseFormat: Task<AwaitedEdition?, Never>] = [:]
    @State private var awaitFailed: String?
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
                        isSaving: viewModel.isSaving,
                        onSetStatus: { status in run { await viewModel.setStatus(status) } },
                        onRate: { showRatingPrompt = true },
                        onToggleHidden: { run { await viewModel.setHidden(!book.hidden) } },
                        onOpenSeries: {
                            openSeries = book.series.map {
                                SeriesDestination(seriesId: $0.id, language: book.language)
                            }
                        },
                        onEditGenre: { showGenreEditor = true },
                        onEditRecommendation: { showRecommendation = true },
                        onEditNote: { showNote = true },
                        onEditField: { editedField = $0 },
                        onCorrect: { correction in
                            run { _ = await viewModel.save(correction, rating: book.rating) }
                        },
                        awaited: offer.awaited,
                        onStopAwaiting: { edition in Task { await stopAwaiting(edition) } }
                    )
                } else if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    EmptyStateView(
                        systemImage: "book.closed",
                        title: "Livre introuvable",
                        verbatim: viewModel.errorMessage ?? String(localized: "Ce livre n'est plus dans votre bibliothèque.")
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            // Toolbar actions close their menu before the mutation leaves, so the
            // call is made visible by a scrim rather than by the control itself.
            .overlay {
                if viewModel.isRefreshing {
                    ZStack {
                        Color.black.opacity(0.1).ignoresSafeArea()
                        ProgressView("Mise à jour de la fiche…")
                            .padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                } else if viewModel.isSaving {
                    ZStack {
                        Color.black.opacity(0.1).ignoresSafeArea()
                        ProgressView()
                    }
                }
            }
            .disabled(viewModel.isRefreshing)
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
            .sheet(isPresented: $showGenreEditor) {
                if let book = viewModel.book {
                    GenreEditSheet(book: book) { correction in
                        let saved = await viewModel.save(correction, rating: book.rating)
                        if let book = viewModel.book { onChanged(book) }
                        guard !saved else { return nil }
                        defer { viewModel.dismissError() }
                        return viewModel.errorMessage ?? String(localized: "Une erreur est survenue")
                    }
                }
            }
            .sheet(isPresented: $showSeriesJoin) {
                if let book = viewModel.book {
                    SeriesJoinSheet(book: book) { correction in
                        let saved = await viewModel.save(correction, rating: book.rating)
                        if let book = viewModel.book { onChanged(book) }
                        guard !saved else { return nil }
                        defer { viewModel.dismissError() }
                        return viewModel.errorMessage ?? String(localized: "Une erreur est survenue")
                    }
                }
            }
            .sheet(isPresented: $showRecommendation) {
                if let book = viewModel.book {
                    RecommendationSheet(current: book.recommendation) { recommendation in
                        let saved = await viewModel.setRecommendation(recommendation)
                        if let book = viewModel.book { onChanged(book) }
                        guard !saved else { return nil }
                        defer { viewModel.dismissError() }
                        return viewModel.errorMessage ?? String(localized: "Une erreur est survenue")
                    }
                }
            }
            .sheet(isPresented: $showNote) {
                if let book = viewModel.book {
                    NoteSheet(current: book.note) { note in
                        let saved = await viewModel.setNote(note)
                        if let book = viewModel.book { onChanged(book) }
                        guard !saved else { return nil }
                        defer { viewModel.dismissError() }
                        return viewModel.errorMessage ?? String(localized: "Une erreur est survenue")
                    }
                }
            }
            .sheet(item: $editedField) { field in
                if let book = viewModel.book {
                    FieldEditSheet(book: book, field: field) { correction in
                        let saved = await viewModel.save(correction, rating: book.rating)
                        if let book = viewModel.book { onChanged(book) }
                        guard !saved else { return nil }
                        defer { viewModel.dismissError() }
                        return viewModel.errorMessage ?? String(localized: "Une erreur est survenue")
                    }
                }
            }
            .sheet(isPresented: $showRatingPrompt) {
                RatingPromptView(current: viewModel.book?.rating) { stars in
                    showRatingPrompt = false
                    run { await viewModel.rate(stars) }
                }
            }
            .navigationDestination(item: $openSeries) { destination in
                SeriesView(seriesId: destination.seriesId, language: destination.language)
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
        .task { await loadOffer() }
        .alert(
            "Impossible de suivre ce livre",
            isPresented: .init(get: { awaitFailed != nil }, set: { if !$0 { awaitFailed = nil } })
        ) {
            Button("OK", role: .cancel) { awaitFailed = nil }
        } message: {
            Text(awaitFailed ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: .shioriAwaitedEditionsDidChange)) { _ in
            Task { await loadOffer() }
        }
    }

    // MARK: - Awaited editions

    private func loadOffer() async {
        do {
            offer = try await AwaitedAPI.offer(bookId: bookId) ?? EditionOffer()
        } catch {
            _ = reportError(error)
        }
    }

    /// Awaits the book's edition in the app's language. The page shows it
    /// awaited at once, with no loader: the server looks it up on the web
    /// behind, and its answer replaces the line when it comes.
    private func awaitEdition(_ format: ReleaseFormat, of book: Book) {
        let pending = AwaitedEdition.pending(format: format, of: book)
        offer.awaited.append(pending)
        awaiting[format] = Task {
            defer { awaiting[format] = nil }
            do {
                let edition = try await AwaitedAPI.awaitEdition(bookId: bookId, format: format)
                // Unless the reader gave it up meanwhile.
                if let index = offer.awaited.firstIndex(where: { $0.id == pending.id }) {
                    offer.awaited[index] = edition
                }
                return edition
            } catch {
                offer.awaited.removeAll { $0.id == pending.id }
                awaitFailed = reportError(error)
                return nil
            }
        }
    }

    private func stopAwaiting(_ edition: AwaitedEdition) async {
        var edition = edition
        // Given up before the server answered: stopped once it has.
        if let pending = awaiting[edition.format] {
            offer.awaited.removeAll { $0.id == edition.id }
            guard let answered = await pending.value else { return }
            edition = answered
        }
        do {
            try await AwaitedAPI.stop(id: edition.id)
            offer.awaited.removeAll { $0.id == edition.id }
        } catch {
            awaitFailed = reportError(error)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) { dismiss() }
        }
        if let book = viewModel.book {
            // The heart gets the corner to itself rather than a line in the menu:
            // it is the one action a reader takes over and over, and burying a
            // one-tap gesture two taps deep is what the menu is for avoiding.
            ToolbarItem(placement: .primaryAction) {
                ToolbarIconButton(
                    title: book.favorite ? "Retirer des favoris" : "Ajouter aux favoris",
                    systemImage: book.favorite ? "heart.fill" : "heart"
                ) {
                    run { await viewModel.setFavorite(!book.favorite) }
                }
                .tint(book.favorite ? .red : nil)
                .accessibilityIdentifier("book-favorite")
            }
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

            // As on an author's page: the book looked up again, for a record
            // scanned thin or before the scan knew better. Typed corrections
            // stay with "Modifier"; this one rewrites only what the web says.
            Button("Mettre à jour", systemImage: "arrow.clockwise") {
                run { await viewModel.refresh() }
            }
            .accessibilityIdentifier("book-refresh")

            // A volume the scan did not recognise as one is filed from here,
            // without going through the whole edit form. Only for a book in no
            // saga: a filed one changes series from the edit form.
            if book.series == nil {
                Button("Ajouter à une série", systemImage: "square.stack") {
                    showSeriesJoin = true
                }
                .accessibilityIdentifier("book-join-series")
            }

            // As in Vinarium: who pressed the book on the reader, picked from
            // their contacts. Once recorded, it is also corrected from its own
            // section on the page.
            Button("Conseillé par…", systemImage: "person.badge.plus") {
                showRecommendation = true
            }
            .accessibilityIdentifier("book-recommend")

            // Its French edition watched for and announced the day it is out:
            // translated or recorded for a book in another language, recorded
            // for a printed one in French, shown out at once when a store
            // sells it already.
            ForEach(offer.awaitable) { format in
                Button(format.awaitLabel, systemImage: format == .audiobook ? "headphones" : "character.book.closed") {
                    awaitEdition(format, of: book)
                }
                .accessibilityIdentifier("book-await-\(format.rawValue)")
            }
            ForEach(offer.awaited) { edition in
                Button(
                    edition.format == .audiobook
                        ? String(localized: "Ne plus guetter en audio")
                        : String(localized: "Ne plus guetter en français"),
                    systemImage: "bell.slash"
                ) {
                    Task { await stopAwaiting(edition) }
                }
            }

            // Not on the segmented picker, which holds the states a book moves
            // through: dropping one is an ending, chosen once, from here.
            if book.status == .dropped {
                Button("Reprendre", systemImage: "arrow.uturn.backward") {
                    run { await viewModel.setStatus(.reading) }
                }
                .accessibilityIdentifier("book-resume")
            } else {
                Button("Abandonner", systemImage: "hand.thumbsdown") {
                    run { await viewModel.setStatus(.dropped) }
                }
                .accessibilityIdentifier("book-drop")
            }

            Button("Supprimer", systemImage: "trash", role: .destructive) {
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
            "Supprimer ce livre ?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
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
