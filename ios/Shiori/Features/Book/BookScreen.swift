import SwiftUI

/// One book's coordinator, pushed over the list that opened it or set beside
/// it on an unfolded iPhone Duo: owns the view model, the toolbar menu, the
/// edit form, the rating prompt, the delete confirmation, filing a standalone
/// book into a saga, and the hop to the series screen.
///
/// It lives on the stack of whoever opens it, so the saga and an awaited
/// edition push after it and Back walks the reader home.
struct BookScreen: View {
    let bookId: String
    var onChanged: (Book) -> Void = { _ in }
    var onDeleted: (String) -> Void = { _ in }

    @State private var viewModel: BookViewModel
    @State private var showEditor = false
    /// Whether the page is laid out as two pages, on an unfolded iPhone Duo:
    /// the edit form then takes the second page rather than a sheet.
    @State private var isSpread = false
    @State private var showGenreEditor = false
    @State private var showSeriesJoin = false
    @State private var showRecommendation = false
    @State private var showNote = false
    @State private var showCoverPicker = false
    @State private var showRatingPrompt = false
    @State private var editedField: BookField?
    @State private var openSeries: SeriesDestination?
    @State private var openAwaited: AwaitedEdition?
    /// Another volume of the saga, from the row of volumes.
    @State private var openVolume: Book?
    @Environment(\.dismiss) private var dismissPresentation
    @Environment(\.detailClosing) private var closing

    /// Pops the screen, closes its sheet, or empties the detail column it
    /// fills on an unfolded iPhone Duo.
    private func dismiss() { closing.close(dismissPresentation) }

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
        Group {
            if let book = viewModel.book {
                BookPage(
                    book: book,
                    isSaving: viewModel.isSaving,
                    onSetStatus: { status in run { await viewModel.setStatus(status) } },
                    onRate: { showRatingPrompt = true },
                    onOpenSeries: {
                        openSeries = book.series.map {
                            SeriesDestination(seriesId: $0.id, language: book.language)
                        }
                    },
                    onEdit: { showEditor = true },
                    onEditGenre: { showGenreEditor = true },
                    onEditRecommendation: { showRecommendation = true },
                    onEditNote: { showNote = true },
                    onEditField: { editedField = $0 },
                    // This volume as the page has it, its status just changed
                    // included.
                    seriesVolumes: viewModel.sagaVolumes.map { $0.id == book.id ? book : $0 },
                    onOpenVolume: { openVolume = $0 },
                    awaited: viewModel.offer.awaited,
                    onOpenAwaited: { openAwaited = $0 },
                    onStopAwaiting: { edition in Task { await viewModel.stopAwaiting(edition) } },
                    secondPage: showEditor && isSpread
                        ? AnyView(editor(book, onClose: { showEditor = false }))
                        : nil
                )
            } else if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                EmptyState(
                    systemImage: "book.closed",
                    title: "Livre introuvable",
                    verbatim: viewModel.errorMessage ?? String(localized: "Ce livre n'est plus dans votre bibliothèque.")
                )
            }
        }
        .onPreferenceChange(TwoPagesShownKey.self) { isSpread = $0 }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        // The AI at work — a shelf book described on its first opening:
        // said in the bar, so the page under it stays readable and every
        // action stays at hand.
        .generatingInBar(viewModel.isDescribing ? "L'IA complète la fiche" : nil)
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
        .pushesDetail(item: $openAwaited) { edition in
            AwaitedEditionScreen(edition: edition) {
                Task { await viewModel.stopAwaiting(edition) }
            }
        }
        // A sheet on one page; on two, the form takes the reading's page.
        .sheet(isPresented: Binding(get: { showEditor && !isSpread }, set: { showEditor = $0 })) {
            if let book = viewModel.book {
                editor(book, onClose: nil)
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
        .sheet(isPresented: $showCoverPicker) {
            if let book = viewModel.book {
                CoverPickerSheet(
                    book: book,
                    choices: viewModel.coverChoices,
                    loadFailed: viewModel.coverChoicesFailed
                ) { choice in
                    let chosen = await viewModel.chooseCover(choice)
                    if let book = viewModel.book { onChanged(book) }
                    guard !chosen else { return nil }
                    defer { viewModel.dismissError() }
                    return viewModel.errorMessage ?? String(localized: "Une erreur est survenue")
                }
                .task { await viewModel.loadCoverChoices() }
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
        .pushesDetail(item: $openSeries) { destination in
            SeriesScreen(seriesId: destination.seriesId, language: destination.language)
        }
        .pushesDetail(item: $openVolume) { volume in
            BookScreen(bookId: volume.id, client: client)
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
        .task {
            // What the search offers first, before a word is typed.
            RecentlyViewed().remember(bookId)
            await viewModel.load()
            await viewModel.loadSagaVolumes()
            // The row behind the page follows: a shelf book's cover may change.
            if await viewModel.describeIfAwaiting(), let book = viewModel.book { onChanged(book) }
        }
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
        // Pushed, the system's Back button closes the page.
        if closing.showsCloseButton {
            ToolbarItem(placement: .cancellationAction) {
                ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) { dismiss() }
            }
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
            case .chooseCover: showCoverPicker = true
            case .joinSeries: showSeriesJoin = true
            case .recommend: showRecommendation = true
            case let .awaitEdition(format): viewModel.awaitEdition(format)
            case let .stopAwaiting(edition): Task { await viewModel.stopAwaiting(edition) }
            case let .setStatus(status): run { await viewModel.setStatus(status) }
            case .toggleHidden: run { await viewModel.setHidden(!book.hidden) }
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
    /// The form that changes the book's title, authors and facts. `onClose`
    /// is set where it fills the second page rather than a sheet.
    private func editor(_ book: Book, onClose: (() -> Void)?) -> some View {
        BookEditSheet(book: book, loadVocabulary: loadVocabulary, onClose: onClose) { correction, rating in
            let saved = await viewModel.save(correction, rating: rating)
            if let book = viewModel.book { onChanged(book) }
            guard !saved else { return nil }
            // The form shows the failure itself: an alert hung on this
            // screen would stay hidden behind the form's sheet.
            defer { viewModel.dismissError() }
            return viewModel.errorMessage ?? String(localized: "Une erreur est survenue")
        }
    }

    private func run(_ operation: @escaping () async -> Void) {
        Task {
            await operation()
            if let book = viewModel.book { onChanged(book) }
        }
    }
}

#Preview {
    NavigationStack {
        BookScreen(bookId: "preview", client: .preview)
    }
}
