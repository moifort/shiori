import SwiftUI

/// The two ways the reader holds a book, as the author's page tells them apart:
/// on paper or a screen, and as a recording. Releases come out on different days
/// in each, and a reader who listens to an author does not own them in print.
enum AuthorShelfFormat: String, CaseIterable, Identifiable {
    case print, audio
    var id: String { rawValue }

    var label: String {
        switch self {
        case .print: String(localized: "Livre")
        case .audio: String(localized: "Audio")
        }
    }

    var symbol: String {
        switch self {
        case .print: "book.closed"
        case .audio: "headphones"
        }
    }

    func holds(_ book: Book) -> Bool {
        (book.format == .audiobook) == (self == .audio)
    }

    /// What a book added from the page is catalogued as.
    var bookFormat: BookFormat { self == .audio ? .audiobook : .book }
}

/// An author's page, laid out as a saga's is: who they are and what the reader
/// made of them, then — through a Livre / Audio switch that filters everything
/// below it, a saga heard being a saga of its own — their sagas and their books outside any saga, what the reader holds
/// first and what they could add after, each with a `+` that puts it on the pile.
///
/// The first opening, by anyone, builds the author's shared catalogue on the
/// server, portrait included, which takes a few seconds; every later one reads it.
struct AuthorView: View {
    let key: String
    let name: String
    /// Opened as a sheet — from the Authors shelf, as a book opens from the
    /// library — rather than pushed: a close button in the corner.
    var isSheet = false

    @Environment(\.dismiss) private var dismiss
    @State private var page: AuthorPage?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var format: AuthorShelfFormat?
    @State private var adding: String?
    @State private var selectedBook: Book?
    @State private var openSeries: SeriesDestination?
    /// The refresh is one grounded model call and takes a while.
    @State private var isRefreshing = false
    /// The refresh came back with nothing: the page on screen is the old one.
    @State private var refreshFailed = false

    var body: some View {
        Group {
            if isLoading && page == nil {
                ProgressView("Chargement de la fiche…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let page {
                content(page)
            } else {
                EmptyStateView.failure(
                    "Fiche indisponible",
                    message: errorMessage ?? String(localized: "Aucun livre de cet auteur dans votre bibliothèque.")
                ) { await load() }
            }
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $selectedBook) { book in
            BookView(
                bookId: book.id,
                onChanged: { _ in Task { await load() } },
                onDeleted: { _ in Task { await load() } }
            )
        }
        .navigationDestination(item: $openSeries) {
            SeriesView(seriesId: $0.seriesId, language: $0.language, proposal: $0.proposal)
        }
        // Back from a saga, read again: a volume added there moves the saga
        // among the reader's own, and a rating changes its row.
        .onChange(of: openSeries) { _, destination in
            if destination == nil { Task { await load() } }
        }
        .toolbar {
            if isSheet {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) { dismiss() }
                }
            }
            if page != nil {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Mettre à jour la fiche", systemImage: "arrow.clockwise") {
                            Task { await refreshCatalogue() }
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
        .alert("Fiche non mise à jour", isPresented: $refreshFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Shiori n'a rien trouvé de plus sur cet auteur. L'ancienne fiche est conservée ; réessayez plus tard.")
        }
        .overlay {
            if isRefreshing {
                ZStack {
                    Color.black.opacity(0.1).ignoresSafeArea()
                    ProgressView("Mise à jour de la fiche…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .disabled(isRefreshing)
        .alert(
            "Une erreur est survenue",
            isPresented: .init(
                get: { errorMessage != nil && page != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func content(_ page: AuthorPage) -> some View {
        let shown = format ?? usualFormat(page)
        return List {
            header(page)
            Section {
                Picker("Format", selection: Binding(get: { shown }, set: { format = $0 })) {
                    ForEach(AuthorShelfFormat.allCases) { format in
                        Label(format.label, systemImage: format.symbol).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .accessibilityIdentifier("author-format")
            }
            sagas(page, in: shown)
            books(page, in: shown)
        }
        .listStyle(.insetGrouped)
        .labelStyle(.row)
    }

    // MARK: - Header

    private func header(_ page: AuthorPage) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 16) {
                    AuthorAvatar(initials: page.author.initials, portraitURL: page.author.portraitURL, size: 84)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(page.author.name)
                            .font(.title3.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                            .copyable(page.author.name)
                        if let origin = origin(page) {
                            Text(origin)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text(figures(page.author))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                    Spacer(minLength: 0)
                }
                if let biography = page.biography {
                    Text(biography)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .copyable(biography)
                }
            }
            .padding(.vertical, 6)

            if page.author.favoriteCount > 0 {
                LabeledInfoRow(title: "Coups de cœur", value: "\(page.author.favoriteCount)", icon: "heart")
            }
            if let rating = page.author.averageRating {
                Label {
                    LabeledContent("Note moyenne") {
                        HStack(spacing: 6) {
                            StarRatingView(rating: Int(rating.rounded()), font: .subheadline)
                            Text(rating, format: .number.precision(.fractionLength(1)))
                                .foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: "star").foregroundStyle(.secondary)
                }
            }
            LabeledInfoRow(title: "Lus", value: "\(page.readCount)", icon: "checkmark")
        }
    }

    /// "Américain · 1975", "Française · 1903 – 1987". The year alone rather
    /// than "né en": the word would have to agree with an author the app does
    /// not know the gender of.
    private func origin(_ page: AuthorPage) -> String? {
        let years: String? = switch (page.birthYear, page.deathYear) {
        case let (born?, died?): "\(String(born)) – \(String(died))"
        case let (born?, nil): String(born)
        default: nil
        }
        let parts = [page.nationality, years].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func figures(_ author: FollowedAuthor) -> String {
        let books = author.bookCount == 1
            ? String(localized: "1 livre")
            : String(localized: "\(author.bookCount) livres")
        switch author.seriesCount {
        case 0: return books
        case 1: return String(localized: "\(books), 1 série")
        default: return String(localized: "\(books), \(author.seriesCount) séries")
        }
    }

    /// The format the reader holds most of this author in: a reader who listens
    /// to them opens on their recordings.
    private func usualFormat(_ page: AuthorPage) -> AuthorShelfFormat {
        let held = page.sagas.flatMap(\.volumes) + page.books
        let audio = held.filter { AuthorShelfFormat.audio.holds($0) }.count
        return audio > held.count - audio ? .audio : .print
    }

    // MARK: - Sagas

    /// The sagas of the format on screen: the saga heard is a saga of its own,
    /// with its own spine, so the switch shows one or the other whole.
    @ViewBuilder
    private func sagas(_ page: AuthorPage, in format: AuthorShelfFormat) -> some View {
        let held = page.sagas.filter { $0.isAudio == (format == .audio) }
        let notHeld = page.sagasNotHeld(in: format)
        if !held.isEmpty || !notHeld.isEmpty {
            Section("Séries") {
                ForEach(held) { saga in
                    // A tap rather than a button, as on the Series tab: a
                    // button would claim the drag that scrolls the covers.
                    SeriesRow(entry: saga, showsAuthor: false)
                        .contentShape(Rectangle())
                        .onTapGesture { openSeries = SeriesDestination(seriesId: saga.seriesId, language: saga.language) }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                        .edgeToEdgeSeparator()
                        .accessibilityIdentifier("author-saga")
                }
                ForEach(notHeld) { saga in
                    sagaNotHeld(saga, author: page.author.name, in: format)
                        .edgeToEdgeSeparator()
                }
            }
        }
    }

    /// Opens on the saga screen, as a saga the reader holds does: the server
    /// catalogues it there from the name and author the page gives.
    private func sagaNotHeld(_ saga: AuthorSeries, author: String, in format: AuthorShelfFormat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(saga.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer(minLength: 0)
                addButton(id: saga.id, label: "Commencer « \(saga.name) »") {
                    await start(saga, author: author, format: format)
                }
            }
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(1...max(1, min(saga.volumeCount ?? 1, 12)), id: \.self) { number in
                        BookCover(
                            book: Book(id: "\(saga.id)-\(number)", title: saga.name, authors: [author], status: .toRead),
                            width: 44,
                            showsFormatBadge: false
                        )
                        .opacity(0.35)
                        .overlay(alignment: .bottom) {
                            Text(verbatim: "\(number)")
                                .font(.caption2.weight(.bold).monospacedDigit())
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 4)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .accessibilityHidden(true)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            openSeries = SeriesDestination(seriesId: saga.id, language: nil, proposal: saga.proposal)
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("author-saga-not-held")
    }

    // MARK: - Books

    @ViewBuilder
    private func books(_ page: AuthorPage, in format: AuthorShelfFormat) -> some View {
        let held = page.books.filter(format.holds)
        if !held.isEmpty || !page.booksNotHeld.isEmpty {
            Section("Livres") {
                ForEach(held) { book in
                    Button { selectedBook = book } label: {
                        BookRow(
                            title: book.title,
                            // The page is the author's: their name on every
                            // row would say nothing.
                            authorLine: "",
                            cover: book,
                            status: book.status,
                            rating: book.shownRating,
                            ratingIsInherited: book.ratingIsInherited,
                            publishedIn: book.firstPublishedIn,
                            statusTag: book.status,
                            isFavorite: book.favorite,
                            isHidden: book.hidden
                        )
                    }
                    .tint(.primary)
                    .edgeToEdgeSeparator()
                    .accessibilityIdentifier("author-book")
                }
                ForEach(page.booksNotHeld) { work in
                    workNotHeld(work, author: page.author.name, in: format)
                        .edgeToEdgeSeparator()
                }
            }
        }
    }

    private func workNotHeld(_ work: AuthorWork, author: String, in format: AuthorShelfFormat) -> some View {
        HStack(alignment: .center, spacing: 12) {
            BookCover(book: Book(id: work.id, title: work.title, authors: [author], status: .toRead))
                .opacity(0.45)
            VStack(alignment: .leading, spacing: 3) {
                Text(work.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if let year = work.publishedIn {
                    Text(verbatim: String(year))
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 8)
            addButton(id: work.id, label: "Ajouter « \(work.title) » à ma liste à lire") {
                await add(title: work.title, author: author, series: nil, format: format)
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("author-book-not-held")
    }

    // MARK: - Adding

    private func addButton(id: String, label: LocalizedStringKey, action: @escaping () async -> Void) -> some View {
        Group {
            if adding == id {
                ProgressView().controlSize(.small)
            } else {
                Button { Task { await action() } } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text(label))
            }
        }
    }

    /// A saga is started with its first volume, filed into the saga so it joins
    /// the Series tab and the saga screen at once.
    private func start(_ saga: AuthorSeries, author: String, format: AuthorShelfFormat) async {
        adding = saga.id
        defer { adding = nil }
        await add(
            title: saga.firstVolumeTitle ?? saga.name,
            author: author,
            series: SeriesMembership(id: saga.id, name: saga.name, volume: 1, kind: .main),
            format: format
        )
    }

    /// Onto the pile, as the saga screen adds a missing volume: a title lookup
    /// first for the cover and the details, the author, the saga and the format
    /// of the page kept whatever the lookup answered.
    private func add(title: String, author: String, series: SeriesMembership?, format: AuthorShelfFormat) async {
        if adding == nil { adding = title }
        defer { if adding == title { adding = nil } }
        var draft = BookDraft(title: title, authors: [author], format: format.bookFormat)
        if let found = try? await ScanAPI.lookUp(title: "\(title) — \(author)"), found.recognized {
            draft = found.asDraft
            if draft.title.isEmpty { draft.title = title }
            if draft.authors.isEmpty { draft.authors = [author] }
        }
        draft.format = format.bookFormat
        draft.series = series
        draft.status = .toRead
        do {
            _ = try await BookAPI.add(draft)
            track(.bookAdded(source: .author))
            await load()
        } catch {
            errorMessage = reportError(error)
        }
    }

    /// Asks the world about the author again. The page is read afresh when the
    /// catalogue was rebuilt; otherwise the reader is told the old one stands.
    private func refreshCatalogue() async {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            if try await AuthorsAPI.refresh(key: key) {
                await load()
            } else {
                refreshFailed = true
            }
        } catch {
            errorMessage = reportError(error)
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fresh = try await AuthorsAPI.page(key: key)
            withAnimation(page == nil ? nil : .smooth) { page = fresh }
            if fresh == nil { errorMessage = nil }
        } catch {
            guard !isCancellation(error) else { return }
            errorMessage = reportError(error)
        }
    }
}
