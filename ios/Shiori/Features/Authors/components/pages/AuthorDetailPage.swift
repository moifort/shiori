import SwiftUI

/// Everything an author's page can ask for.
enum AuthorAction {
    case openBook(Book)
    case openSeries(SeriesDestination)
    /// A book of theirs the reader does not hold, opened to be added.
    case openWork(AuthorWork)
    case menu(Book, BookQuickAction)
    case refresh
}

/// An author's page, as the TV app draws a person: their round portrait over
/// their first cover blurred, the name, where they come from and
/// when they were born, three lines of biography, then their figures. Under
/// it, their series as the cards of "Toutes les séries", their books outside
/// any series on two rows that scroll together, and what the reader does not
/// hold yet — announced, or never added — dimmed: a tap opens it.
struct AuthorDetailPage: View {
    let name: String
    /// Nil until the server answered, or when the reader holds nothing of them.
    let page: AuthorPage?
    let isLoading: Bool
    let errorMessage: String?
    let onAction: (AuthorAction) async -> Void

    private static let portraitSize: CGFloat = 160
    /// Fewer and a second row would stand half empty.
    private static let twoRowsFrom = 6

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
        .background(Color(.systemGroupedBackground))
        // The name stays the page's title for the Back button's history, but
        // the bar does not show it: the hero says it, as on a book's page.
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(removing: .title)
        .refreshable { await onAction(.refresh) }
    }

    private func send(_ action: AuthorAction) {
        Task { await onAction(action) }
    }

    private func content(_ page: AuthorPage) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                hero(page)
                seriesSection(page)
                booksSection(page)
                discoverSection(page)
            }
            .padding(.bottom, 32)
        }
        // The bar's buttons float over the portrait as it scrolls, as on a book's.
        .scrollEdgeEffectHidden(true, for: .top)
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Hero

    private func hero(_ page: AuthorPage) -> some View {
        VStack(spacing: 14) {
            AuthorAvatar(initials: page.author.initials, portraitURL: page.author.portraitURL, size: Self.portraitSize)
                .shadow(color: .black.opacity(0.4), radius: 18, y: 10)
                .padding(.top, 128)
            VStack(spacing: 4) {
                Text(page.author.name)
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                    .copyable(page.author.name)
                if let origin = origin(page) {
                    Text(origin)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            if let biography = page.biography {
                PersonBiography(text: biography)
                    .padding(.horizontal, 20)
            }
            figures(page)
                .padding(.horizontal, 20)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            // The colours run on under the name and its origin, and melt into
            // the page across the biography.
            CoverBackdrop(url: page.backdropURL, fadeHeight: 240, ground: Color(.systemGroupedBackground))
                .frame(height: 600)
        }
    }

    private func origin(_ page: AuthorPage) -> String? {
        PersonBiography.origin(nationality: page.nationality, birthYear: page.birthYear, deathYear: page.deathYear)
    }

    /// The author's figures, spread across the width: read, on the pile, the
    /// mean of the stars, the series.
    private func figures(_ page: AuthorPage) -> some View {
        let held = page.books + page.sagas.flatMap(\.volumes)
        let pile = held.filter { $0.status == .toRead }.count
        var items: [(value: String, label: String)] = [
            (page.readCount.formatted(), String(localized: "lus")),
            (pile.formatted(), String(localized: "à lire")),
        ]
        if let rating = page.author.averageRating {
            items.append(("★ \(rating.formatted(.number.precision(.fractionLength(1))))", String(localized: "moyenne")))
        }
        let series = page.author.seriesCount
        items.append((series.formatted(), series > 1 ? String(localized: "séries") : String(localized: "série")))
        return HStack(alignment: .top) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(spacing: 2) {
                    Text(item.value)
                        .font(.headline)
                    Text(item.label.localizedUppercase)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Sections

    @ViewBuilder
    private func seriesSection(_ page: AuthorPage) -> some View {
        if !page.sagas.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                RowHeader(title: "Séries", style: .inline).padding(.horizontal, 20)
                SeriesCardRail(series: page.sagas) { saga in
                    send(.openSeries(SeriesDestination(seriesId: saga.seriesId)))
                }
            }
        }
    }

    @ViewBuilder
    private func booksSection(_ page: AuthorPage) -> some View {
        if !page.books.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                RowHeader(title: "Livres", style: .inline).padding(.horizontal, 20)
                PosterRow(
                    items: page.books.map { .init(book: $0, label: PosterLabel.of($0, in: .recent)) },
                    rows: page.books.count >= Self.twoRowsFrom ? 2 : 1,
                    onOpen: { send(.openBook($0)) },
                    onMenu: { book, action in send(.menu(book, action)) }
                )
                .contentMargins(.horizontal, 20, for: .scrollContent)
            }
        }
    }

    /// What the reader does not hold: the volumes announced of their series,
    /// the series never started, the books never added — dimmed, the year or
    /// the date in the cover.
    @ViewBuilder
    private func discoverSection(_ page: AuthorPage) -> some View {
        let items = discoveries(page)
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                RowHeader(title: "À découvrir", style: .inline).padding(.horizontal, 20)
                PosterRow(items: items) { _ in }
                    .contentMargins(.horizontal, 20, for: .scrollContent)
            }
        }
    }

    private func discoveries(_ page: AuthorPage) -> [PosterRow.Item] {
        let author = page.author.name
        let announced: [PosterRow.Item] = page.sagas.compactMap { saga in
            guard let release = saga.nextRelease else { return nil }
            let book = Book(
                id: "announced-\(saga.id)",
                title: release.title,
                authors: [author],
                format: saga.isAudio ? .audiobook : .book,
                coverURL: release.coverURL,
                status: .toRead
            )
            return PosterRow.Item(
                book: book,
                label: PosterLabel(caption: ReleaseDateText.short(release.date), dimming: PosterLabel.setAsideDimming),
                open: { send(.openSeries(SeriesDestination(seriesId: saga.seriesId))) }
            )
        }
        let sagas: [PosterRow.Item] = page.sagasNotHeld.map { saga in
            let book = Book(
                id: "saga-\(saga.id)",
                title: saga.name,
                authors: [author],
                format: saga.isAudio ? .audiobook : .book,
                coverURL: saga.coverURL,
                status: .toRead
            )
            return PosterRow.Item(
                book: book,
                label: PosterLabel(caption: String(localized: "Série"), dimming: PosterLabel.setAsideDimming),
                open: { send(.openSeries(SeriesDestination(seriesId: saga.id, proposal: saga.proposal))) }
            )
        }
        let works: [PosterRow.Item] = page.booksNotHeld.map { work in
            let book = Book(id: "work-\(work.id)", title: work.title, authors: [author], coverURL: work.coverURL, status: .toRead)
            return PosterRow.Item(
                book: book,
                label: PosterLabel(
                    caption: work.publishedIn.map { String($0) } ?? "",
                    dimming: PosterLabel.setAsideDimming
                ),
                open: { send(.openWork(work)) }
            )
        }
        return announced + sagas + works
    }
}

#Preview {
    NavigationStack {
        AuthorDetailPage(name: "Robin Hobb", page: .preview, isLoading: false, errorMessage: nil) { _ in }
    }
}

#Preview("Holds nothing of them") {
    NavigationStack {
        AuthorDetailPage(name: "Robin Hobb", page: nil, isLoading: false, errorMessage: nil) { _ in }
    }
}
