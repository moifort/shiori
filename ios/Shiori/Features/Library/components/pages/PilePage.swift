import SwiftUI

/// Everything the pile's page can ask for.
enum PileAction {
    case openBook(Book)
    case openSeries(FollowedSeries)
    case selectGenre(BookGenre?)
    case menu(Book, BookQuickAction)
    case openWishlist
    case refresh
}

/// "Pile à lire", for choosing the next book: a rail per reason to read one —
/// what was begun, the next volume of each saga in progress as the series
/// screen's "À suivre" draws it, what someone recommended, the favourite
/// authors and narrators, the award winners, the authors never read. The pills narrow every rail to a genre.
struct PilePage: View {
    let pile: Pile
    /// What can be had now from the wishlist, each cover labelled with where it
    /// came from: a rail after the books begun, opening the list.
    var wished: [PosterRow.Item] = []
    /// The series screen's "À suivre", narrowed to the pills: a rail after
    /// the books begun, above the wishlist's.
    var upNext: [(series: FollowedSeries, volume: FollowedSeries.NextVolume)] = []
    var genres: [BookGenre] = []
    var selectedGenre: BookGenre?
    let isLoading: Bool
    let errorMessage: String?
    let onAction: (PileAction) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                pills
                if sections.isEmpty, upNext.isEmpty {
                    empty
                } else {
                    if sections.first?.kind != .toFinish { followOn }
                    ForEach(sections) { section in
                        rail(section)
                        if section.kind == .toFinish { followOn }
                    }
                }
            }
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(BookShelf.toRead.title)
        .navigationBarTitleDisplayMode(.large)
        .refreshable { onAction(.refresh) }
    }

    /// The server's sections but its "La suite", which "À suivre" replaces.
    private var sections: [PileSection] {
        pile.sections.filter { $0.kind != .nextVolume }
    }

    /// What comes after the books begun: "À suivre", then the wishlist.
    @ViewBuilder private var followOn: some View {
        if !upNext.isEmpty {
            SeriesUpNextRail(upNext: upNext) { onAction(.openSeries($0)) }
        }
        wishRail
    }

    @ViewBuilder private var pills: some View {
        if genres.count > 1 {
            FilterPills(
                pills: genres.map { FilterPills.Pill(id: $0.rawValue, label: $0.label) },
                selected: selectedGenre?.rawValue
            ) { onAction(.selectGenre($0.flatMap(BookGenre.init(rawValue:)))) }
        }
    }

    private func rail(_ section: PileSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            RowHeader(title: LocalizedStringKey(section.kind.title), style: .inline)
                .padding(.horizontal, 20)
            PosterRow(
                items: section.picks.map { .init(book: $0.book, label: section.label(of: $0)) },
                onOpen: { onAction(.openBook($0)) },
                onMenu: { onAction(.menu($0, $1)) }
            )
            .contentMargins(.horizontal, 20, for: .scrollContent)
        }
        .accessibilityIdentifier("pile-section-\(section.kind.rawValue)")
    }

    @ViewBuilder private var wishRail: some View {
        if !wished.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                RowHeader(title: "Liste d'envies", style: .inline) { onAction(.openWishlist) }
                    .padding(.horizontal, 20)
                PosterRow(items: wished) { _ in onAction(.openWishlist) }
                    .contentMargins(.horizontal, 20, for: .scrollContent)
            }
            .accessibilityIdentifier("pile-section-wishlist")
        }
    }

    @ViewBuilder private var empty: some View {
        if let errorMessage, !isLoading {
            EmptyState.failure("Pile indisponible", message: errorMessage) { onAction(.refresh) }
                .padding(.top, 60)
        } else if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
        } else {
            EmptyState(
                systemImage: "book.pages",
                title: "Pile vide",
                message: "Les livres à lire et ceux en cours s'afficheront ici."
            )
            .padding(.top, 60)
        }
    }
}

#if DEBUG
#Preview("Pile") {
    NavigationStack {
        PilePage(
            pile: Showcase.pile(view: ShelvesView()),
            upNext: Showcase.seriesPage(limit: 200, after: nil, mode: .all, state: nil).items.filter { !$0.isSetAside }.upNext,
            genres: Showcase.pile(view: ShelvesView()).genres,
            isLoading: false,
            errorMessage: nil
        ) { _ in }
    }
}

#Preview("Empty") {
    NavigationStack {
        PilePage(pile: Pile(), isLoading: false, errorMessage: nil) { _ in }
    }
}
#endif
