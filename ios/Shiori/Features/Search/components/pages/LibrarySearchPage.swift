import SwiftUI

/// The search over the reader's own books, pure: the field, the filter chips
/// under it, and what the query finds — the sagas first, then the books.
/// Without a query it offers the recent searches, and the books a filter keeps.
struct LibrarySearchPage: View {
    @Binding var query: String
    let filter: SearchFilter
    let results: SearchResults
    let recentSearches: [String]
    /// The books opened last, anywhere in the app: offered before a word is typed.
    var recentlyViewed: [Book] = []
    /// Covers fetched for the rows, by book id: the index carries none.
    let covers: [String: URL]
    let isPreparing: Bool
    let failed: Bool
    let isSearching: Bool
    let onAction: (Action) async -> Void

    enum Action {
        case openBook(Book)
        case openSeries(SeriesHit)
        case toggleFavorites
        case select(ReadingStatus)
        case clearFilter
        case useRecent(String)
        case clearRecentSearches
        case retry
        case close
    }

    var body: some View {
        List {
            Section {
                chips
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
            }
            .listSectionSpacing(.compact)
            if isPreparing {
                preparing
            } else if !failed {
                content
            }
        }
        .overlay {
            if failed {
                failure
            } else if showsNoResult {
                noResult
            }
        }
        .listStyle(.insetGrouped)
        .contentMargins(.top, 4, for: .scrollContent)
        .navigationTitle("Rechercher")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text("Titre, auteur, série")
        )
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    Task { await onAction(.close) }
                } label: {
                    Label("Fermer", systemImage: "xmark")
                }
                .accessibilityIdentifier("search-close")
            }
        }
    }

    // MARK: - Filters

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "Favoris", systemImage: "heart.fill", isOn: filter.favorites) {
                    Task { await onAction(.toggleFavorites) }
                }
                ForEach(SearchFilter.statuses) { status in
                    FilterChip(title: chipTitle(status), systemImage: status.symbol, isOn: filter.status == status) {
                        Task { await onAction(.select(status)) }
                    }
                }
            }
        }
        .scrollClipDisabled()
    }

    private func chipTitle(_ status: ReadingStatus) -> LocalizedStringKey {
        switch status {
        case .reading: "En cours"
        case .toRead: "À lire"
        case .read, .dropped: "Lus"
        }
    }

    // MARK: - States

    private var preparing: some View {
        Section {
            VStack(spacing: 10) {
                ProgressView()
                Text("Préparation de vos livres…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
            .listRowBackground(Color.clear)
        }
    }

    private var failure: some View {
        EmptyState.failure(
            "Recherche indisponible",
            message: String(localized: "Vos livres n’ont pas pu être chargés.")
        ) { await onAction(.retry) }
    }

    @ViewBuilder
    private var content: some View {
        let typed = !SearchText.normalized(query).isEmpty
        if !typed, !filter.isActive, !recentlyViewed.isEmpty {
            viewed
        }
        if !typed, !recentSearches.isEmpty {
            recents
        }
        if !typed, !filter.isActive, recentlyViewed.isEmpty, recentSearches.isEmpty {
            help
        }
        if isSearching {
            found
        }
    }

    private var viewed: some View {
        Section("Vus récemment") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(recentlyViewed) { book in
                        Button {
                            Task { await onAction(.openBook(book)) }
                        } label: {
                            CoverTile(book: withCover(book), caption: book.title, width: 72)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("search-viewed")
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollClipDisabled()
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
    }

    private var help: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "binoculars")
                    .font(.system(size: 40))
                Text("Cherchez un titre, un auteur ou une série de votre bibliothèque.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
            }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .listRowBackground(Color.clear)
        }
    }

    private var showsNoResult: Bool {
        !isPreparing && isSearching && results.series.isEmpty && results.books.isEmpty
    }

    private var recents: some View {
        Section {
            ForEach(recentSearches, id: \.self) { recent in
                Button {
                    Task { await onAction(.useRecent(recent)) }
                } label: {
                    Label(recent, systemImage: "clock.arrow.circlepath")
                }
                .tint(.primary)
            }
        } header: {
            HStack {
                Text("Recherches récentes")
                Spacer()
                Button("Effacer") {
                    Task { await onAction(.clearRecentSearches) }
                }
                .font(.subheadline)
                .textCase(nil)
                .accessibilityIdentifier("search-clear-recents")
            }
        }
    }

    @ViewBuilder
    private var found: some View {
        if !results.series.isEmpty {
            Section("Séries") {
                ForEach(results.series) { hit in
                    Button {
                        Task { await onAction(.openSeries(hit)) }
                    } label: {
                        SeriesHitRow(hit: hit, cover: hit.books.first.map(withCover))
                    }
                    .tint(.primary)
                    .accessibilityIdentifier("search-series")
                }
            }
        }
        if !results.books.isEmpty {
            Section {
                ForEach(results.books) { book in
                    Button {
                        Task { await onAction(.openBook(book)) }
                    } label: {
                        BookRow(
                            title: book.title,
                            highlightedTitle: highlighted(book.title),
                            authorLine: book.authorLine,
                            cover: withCover(book),
                            status: book.status,
                            rating: book.shownRating,
                            ratingIsInherited: book.ratingIsInherited,
                            series: book.series,
                            statusTag: book.status,
                            genre: book.genre,
                            subgenre: book.subgenres.first,
                            language: book.language,
                            isFavorite: book.favorite,
                            isHidden: book.hidden,
                            listeningProgress: book.status == .reading ? book.listeningProgressLabel : nil
                        )
                    }
                    .tint(.primary)
                    .accessibilityIdentifier("search-book")
                }
            } header: {
                Text("Livres · \(results.books.count)")
            }
        }
    }

    @ViewBuilder
    private var noResult: some View {
        if results.hiddenByFilter > 0 {
            EmptyState(
                systemImage: "line.3.horizontal.decrease.circle",
                title: "Aucun livre ne correspond",
                verbatim: String(localized: "Hors de ce filtre, \(results.hiddenByFilter) livres correspondent."),
                primary: .init("Retirer le filtre", systemImage: "xmark.circle") { await onAction(.clearFilter) }
            )
            .assetSymbol("book-search")
        } else {
            EmptyState(
                systemImage: "magnifyingglass",
                title: "Aucun livre ne correspond",
                message: "Cherchez un titre, un auteur ou une série de votre bibliothèque."
            )
            .assetSymbol("book-search")
        }
    }

    // MARK: - Rows

    private func withCover(_ book: Book) -> Book {
        guard book.coverURL == nil, let url = covers[book.id] else { return book }
        var covered = book
        covered.coverURL = url
        return covered
    }

    /// The title, its words that the query matched marked.
    private func highlighted(_ title: String) -> AttributedString? {
        guard !SearchText.normalized(query).isEmpty else { return nil }
        var marked = AttributedString(title)
        var found = false
        for match in title.matches(of: /\S+/) {
            guard LibrarySearchMatcher.highlights(String(match.output), for: query),
                  let range = Range(match.range, in: marked)
            else { continue }
            marked[range].backgroundColor = .yellow.opacity(0.35)
            found = true
        }
        return found ? marked : nil
    }
}

/// One chip under the field: a filter, filled while on.
private struct FilterChip: View {
    let title: LocalizedStringKey
    let systemImage: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                Text(title)
            }
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(isOn ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .background(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary), in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// A saga the query found: its first held volume's cover, its name, its authors
/// and how many volumes the reader holds.
private struct SeriesHitRow: View {
    let hit: SeriesHit
    let cover: Book?

    var body: some View {
        HStack(spacing: 12) {
            if let cover {
                BookCover(book: cover, width: 40, showsFormatBadge: false)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(hit.name)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                Text(hit.authors.formatted(.list(type: .and)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("\(hit.books.count) tomes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }
}

#if DEBUG
private struct PagePreview: View {
    @State var query: String
    var filter = SearchFilter()
    var isPreparing = false
    var recents: [String] = []
    var viewed: [Book] = []

    var body: some View {
        let entries = SearchFixtures.library.map(SearchEntry.init)
        NavigationStack {
            LibrarySearchPage(
                query: $query,
                filter: filter,
                results: LibrarySearchMatcher.results(for: query, in: entries, filter: filter),
                recentSearches: recents,
                recentlyViewed: viewed,
                covers: Dictionary(uniqueKeysWithValues: SearchFixtures.library.compactMap { book in
                    book.coverURL.map { (book.id, $0) }
                }),
                isPreparing: isPreparing,
                failed: false,
                isSearching: !SearchText.normalized(query).isEmpty || filter.isActive
            ) { _ in }
        }
    }
}

#Preview("Vide") { PagePreview(query: "", recents: ["sanderson", "frieren"], viewed: Array(SearchFixtures.library.prefix(8))) }
#Preview("Première ouverture") { PagePreview(query: "") }
#Preview("Préparation") { PagePreview(query: "", isPreparing: true) }
#Preview("Favoris") { PagePreview(query: "", filter: SearchFilter(favorites: true), recents: ["sanderson", "frieren"]) }
#Preview("Résultats") { PagePreview(query: "dungeon crawler card") }
#Preview("Aucun résultat") { PagePreview(query: "dungeon", filter: SearchFilter(favorites: true)) }
#endif
