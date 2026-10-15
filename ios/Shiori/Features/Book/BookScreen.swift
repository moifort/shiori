import SwiftUI

/// One book's coordinator, presented as a sheet over the list that opened it:
/// owns the view model, the toolbar menu, the edit form, the rating prompt, the
/// delete confirmation, filing a standalone book into a saga, and the hop to
/// the series screen.
///
/// The sheet carries its own NavigationStack, so the series screen pushes inside
/// it and closing the sheet always lands back on the row the reader tapped.
struct BookScreen: View {
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
    @State private var openSeries: SeriesDestination?
    @State private var openAwaited: AwaitedEdition?
    @Environment(\.dismiss) private var dismiss
    private let client: BookClient

    init(
        bookId: String,
        onChanged: @escaping (Book) -> Void = { _ in },
        onDeleted: @escaping (String) -> Void = { _ in },
        client: BookClient = .live
    ) {
        self.bookId = bookId
        self.onChanged = onChanged
        self.onDeleted = onDeleted
        self.client = client
        _viewModel = State(wrappedValue: BookViewModel(bookId: bookId, client: client))
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
                        awaited: viewModel.offer.awaited,
                        onOpenAwaited: { openAwaited = $0 },
                        onStopAwaiting: { edition in Task { await viewModel.stopAwaiting(edition) } }
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
            .sheet(item: $openAwaited) { edition in
                NavigationStack {
                    AwaitedEditionScreen(edition: edition) {
                        Task { await viewModel.stopAwaiting(edition) }
                    }
                }
            }
            .sheet(isPresented: $showEditor) {
                if let book = viewModel.book {
                    BookEditSheet(book: book, loadVocabulary: loadVocabulary) { correction, rating in
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
                    GenreEditSheet(book: book, loadSubgenres: loadSubgenres) { correction in
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
                    SeriesJoinSheet(book: book, loadVocabulary: loadVocabulary) { correction in
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
                RatingPromptSheet(current: viewModel.book?.rating) { stars in
                    showRatingPrompt = false
                    run { await viewModel.rate(stars) }
                }
            }
            .navigationDestination(item: $openSeries) { destination in
                SeriesScreen(seriesId: destination.seriesId, language: destination.language)
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
        .task { await viewModel.loadOffer() }
        .alert(
            "Impossible de suivre ce livre",
            isPresented: .init(
                get: { viewModel.awaitFailed != nil },
                set: { if !$0 { viewModel.awaitFailed = nil } }
            )
        ) {
            Button("OK", role: .cancel) { viewModel.awaitFailed = nil }
        } message: {
            Text(viewModel.awaitFailed ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: .shioriAwaitedEditionsDidChange)) { _ in
            Task { await viewModel.loadOffer() }
        }
    }

    // MARK: - Vocabulary

    /// The proposals under the edit forms' fields: a convenience, so a failed
    /// read is nil rather than an error.
    private func loadVocabulary() async -> BookVocabulary? {
        try? await client.vocabulary()
    }

    private func loadSubgenres() async -> [String] {
        (try? await client.subgenres()) ?? []
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
        BookActionsMenu(book: book, offer: viewModel.offer) { action in
            switch action {
            case .edit: showEditor = true
            case .refresh: run { await viewModel.refresh() }
            case .joinSeries: showSeriesJoin = true
            case .recommend: showRecommendation = true
            case let .awaitEdition(format): viewModel.awaitEdition(format)
            case let .stopAwaiting(edition): Task { await viewModel.stopAwaiting(edition) }
            case let .setStatus(status): run { await viewModel.setStatus(status) }
            case .delete:
                Task {
                    if await viewModel.delete() {
                        onDeleted(bookId)
                        dismiss()
                    }
                }
            }
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

#Preview {
    BookScreen(bookId: "preview", client: .preview)
}
