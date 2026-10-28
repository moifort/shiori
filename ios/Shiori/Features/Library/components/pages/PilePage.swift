import SwiftUI

/// Everything the pile's page can ask for.
enum PileAction {
    case openBook(Book)
    case selectFormat(BookFormat?)
    case selectGenre(BookGenre?)
    case menu(Book, BookQuickAction)
    case openWholePile
    case refresh
}

/// "Pile à lire", for choosing the next book: a rail per reason to read one —
/// what was begun, what follows on, what someone recommended, the favourite
/// authors and narrators, the award winners, the authors never read — and
/// the whole pile a row away. The pills narrow every rail to a format and a
/// genre.
struct PilePage: View {
    let pile: Pile
    var formats: [BookFormat] = []
    var selectedFormat: BookFormat?
    var genres: [BookGenre] = []
    var selectedGenre: BookGenre?
    let isLoading: Bool
    let errorMessage: String?
    let onAction: (PileAction) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                pills
                if pile.sections.isEmpty {
                    empty
                } else {
                    ForEach(pile.sections) { section in
                        rail(section)
                    }
                    LinkRowGroup {
                        LinkRow(symbol: "square.grid.3x3", title: String(localized: "Toute la pile")) {
                            onAction(.openWholePile)
                        }
                    }
                    .accessibilityIdentifier("pile-whole")
                }
            }
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(BookShelf.toRead.title)
        .refreshable { onAction(.refresh) }
    }

    @ViewBuilder private var pills: some View {
        if formats.count > 1 || genres.count > 1 {
            VStack(alignment: .leading, spacing: 10) {
                if formats.count > 1 {
                    FilterPills(
                        pills: formats.map { FilterPills.Pill(id: $0.rawValue, label: $0.shelfLabel) },
                        selected: selectedFormat?.rawValue
                    ) { onAction(.selectFormat($0.flatMap(BookFormat.init(rawValue:)))) }
                }
                if genres.count > 1 {
                    FilterPills(
                        pills: genres.map { FilterPills.Pill(id: $0.rawValue, label: $0.label) },
                        selected: selectedGenre?.rawValue
                    ) { onAction(.selectGenre($0.flatMap(BookGenre.init(rawValue:)))) }
                }
            }
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
                systemImage: "books.vertical",
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
            formats: Showcase.pile(view: ShelvesView()).formats,
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
