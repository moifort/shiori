import SwiftUI

/// Everything an author's page can ask for.
enum AuthorAction {
    case openBook(Book)
    case openSeries(SeriesDestination)
    /// A saga the reader holds nothing of, started with its first volume.
    case startSaga(AuthorSeries, author: String, format: AuthorShelfFormat)
    case addWork(AuthorWork, author: String, format: AuthorShelfFormat)
    case openAwaited(AwaitedEdition)
    case stopAwaiting(AwaitedEdition)
    case refresh
}

/// An author's page, laid out as a saga's is: who they are and what the reader
/// made of them, then — through a Livre / Audio switch that filters everything
/// below it, a saga heard being a saga of its own — their sagas and their books
/// outside any saga, what the reader holds first, then what they could add,
/// each with a `+` that puts it on the pile.
struct AuthorDetailPage: View {
    let name: String
    /// Nil until the server answered, or when the reader holds nothing of them.
    let page: AuthorPage?
    let releases: [ReleaseFormat: AuthorReleases]
    let isLoading: Bool
    let errorMessage: String?
    /// The saga or the work being added, its "+" turning.
    let adding: String?
    let onAction: (AuthorAction) async -> Void

    /// The side of the switch the reader picked; nil opens on the format they
    /// hold most of this author in.
    @State private var format: AuthorShelfFormat?

    var body: some View {
        Group {
            if isLoading && page == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let page {
                content(page)
            } else {
                EmptyState.failure(
                    "Fiche indisponible",
                    message: errorMessage ?? String(localized: "Aucun livre de cet auteur dans votre bibliothèque.")
                ) { await onAction(.refresh) }
            }
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await onAction(.refresh) }
    }

    private func open(_ destination: SeriesDestination) {
        Task { await onAction(.openSeries(destination)) }
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
            if let shownReleases = releases[shown.releaseFormat], !shownReleases.isEmpty {
                AuthorReleasesSection(
                    releases: shownReleases,
                    author: page.author.name,
                    isAudio: shown == .audio,
                    onOpenAwaited: { edition in Task { await onAction(.openAwaited(edition)) } },
                    onStopAwaiting: { edition in Task { await onAction(.stopAwaiting(edition)) } }
                )
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
                            RatingStars(rating: (rating * 2).rounded() / 2, font: .subheadline)
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
                        .onTapGesture { open(SeriesDestination(seriesId: saga.seriesId)) }
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
                    await onAction(.startSaga(saga, author: author, format: format))
                }
            }
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(1...max(1, min(saga.volumeCount ?? 1, 12)), id: \.self) { number in
                        BookCover(
                            book: placeholderVolume(of: saga, number: number, author: author),
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
            open(SeriesDestination(seriesId: saga.id, proposal: saga.proposal))
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("author-saga-not-held")
    }

    /// A volume of a saga the reader holds nothing of: the first one wears the
    /// cover Open Library found, the others the placeholder.
    private func placeholderVolume(of saga: AuthorSeries, number: Int, author: String) -> Book {
        var book = Book(id: "\(saga.id)-\(number)", title: saga.name, authors: [author], status: .toRead)
        if number == 1 { book.coverURL = saga.coverURL }
        return book
    }

    // MARK: - Books

    @ViewBuilder
    private func books(_ page: AuthorPage, in format: AuthorShelfFormat) -> some View {
        let held = page.books.filter(format.holds)
        let notHeld = page.booksNotHeld(in: format)
        if !held.isEmpty || !notHeld.isEmpty {
            Section("Livres") {
                ForEach(held) { book in
                    Button { Task { await onAction(.openBook(book)) } } label: {
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
                ForEach(notHeld) { work in
                    workNotHeld(work, author: page.author.name, in: format)
                        .edgeToEdgeSeparator()
                }
            }
        }
    }

    private func workNotHeld(_ work: AuthorWork, author: String, in format: AuthorShelfFormat) -> some View {
        HStack(alignment: .center, spacing: 12) {
            BookCover(book: {
                var book = Book(id: work.id, title: work.title, authors: [author], status: .toRead)
                book.coverURL = work.coverURL
                return book
            }())
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
                await onAction(.addWork(work, author: author, format: format))
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("author-book-not-held")
    }

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
}

#Preview {
    NavigationStack {
        AuthorDetailPage(
            name: "Robin Hobb", page: .preview, releases: [:], isLoading: false,
            errorMessage: nil, adding: nil
        ) { _ in }
    }
}

#Preview("Holds nothing of them") {
    NavigationStack {
        AuthorDetailPage(
            name: "Robin Hobb", page: nil, releases: [:], isLoading: false,
            errorMessage: nil, adding: nil
        ) { _ in }
    }
}
