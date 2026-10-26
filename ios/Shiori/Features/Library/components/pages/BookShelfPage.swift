import SwiftUI

/// Everything a shelf's page can ask for.
enum BookShelfAction {
    case openBook(Book)
    case selectStatus(ReadingStatus?)
    case selectFormat(BookFormat?)
    case menu(Book, BookQuickAction)
    case reached(String)
    case loadMore
    case refresh
}

/// One shelf of the Library tab, opened from its rail: its posters three by
/// row, under the shelf's headings — the journal's periods for "Récemment"
/// and the books read, the years for the favourites, none for the pile and
/// the books given up on, which a sentence explains.
struct BookShelfPage: View {
    let shelf: BookShelf
    let sections: [ListSection<Book>]
    /// The pills: the statuses over "Récemment", else the formats held.
    var statuses: [ReadingStatus] = []
    var selectedStatus: ReadingStatus?
    var formats: [BookFormat] = []
    var selectedFormat: BookFormat?
    let isLoading: Bool
    let errorMessage: String?
    let hasMore: Bool
    let loadMoreFailed: Bool
    let onAction: (BookShelfAction) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 13), count: 3)

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                pills
                if let explanation {
                    Text(explanation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                }
                if sections.isEmpty {
                    empty
                }
                ForEach(sections) { section in
                    if !section.title.isEmpty {
                        Text(section.title)
                            .font(.title2.weight(.bold))
                            .padding(.horizontal, 20)
                            .padding(.top, 22)
                            .padding(.bottom, 12)
                            .accessibilityAddTraits(.isHeader)
                    }
                    LazyVGrid(columns: columns, spacing: 13) {
                        ForEach(section.rows) { book in
                            poster(book)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, section.title.isEmpty ? 14 : 0)
                }
                if hasMore {
                    LoadMoreRow(
                        failed: loadMoreFailed,
                        loadingLabel: "Chargement de la suite",
                        onLoadMore: { onAction(.loadMore) }
                    )
                    .padding(.top, 20)
                }
            }
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(shelf.title)
        .refreshable { onAction(.refresh) }
    }

    @ViewBuilder private var pills: some View {
        if !statuses.isEmpty {
            FilterPills(
                pills: statuses.map { FilterPills.Pill(id: $0.rawValue, label: $0.recentPillLabel) },
                selected: selectedStatus?.rawValue
            ) { onAction(.selectStatus($0.flatMap(ReadingStatus.init(rawValue:)))) }
            .padding(.bottom, 4)
        } else if !formats.isEmpty {
            FilterPills(
                pills: formats.map { FilterPills.Pill(id: $0.rawValue, label: $0.shelfLabel) },
                selected: selectedFormat?.rawValue
            ) { onAction(.selectFormat($0.flatMap(BookFormat.init(rawValue:)))) }
            .padding(.bottom, 4)
        }
    }

    private var explanation: String? {
        switch shelf {
        case .dropped:
            String(localized: "Les livres arrêtés en cours de route. Ils ne comptent pas comme lus et n'apparaissent nulle part ailleurs dans la bibliothèque.")
        default: nil
        }
    }

    private func poster(_ book: Book) -> some View {
        Button { onAction(.openBook(book)) } label: {
            GeometryReader { proxy in
                PosterCover(book: book, label: PosterLabel.of(book, in: shelf.context), width: proxy.size.width)
            }
            .aspectRatio(2 / 3, contentMode: .fit)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(book.title), \(PosterLabel.of(book, in: shelf.context).caption)"))
        .bookContextMenu(book) { onAction(.menu(book, $0)) }
        .onAppear { onAction(.reached(book.id)) }
    }

    @ViewBuilder private var empty: some View {
        if let errorMessage, !isLoading {
            EmptyState.failure("Rayon indisponible", message: errorMessage) { onAction(.refresh) }
                .padding(.top, 60)
        } else if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
        } else {
            EmptyState(systemImage: "books.vertical", title: "Rien ici pour l'instant", message: "Les livres de ce rayon s'afficheront ici.")
                .padding(.top, 60)
        }
    }
}

extension ReadingStatus {
    /// The pill over "Récemment" that keeps what moved this way.
    var recentPillLabel: String {
        switch self {
        case .toRead: String(localized: "Ajoutés")
        case .reading: String(localized: "En cours")
        case .read: String(localized: "Terminés")
        case .dropped: String(localized: "Abandonnés")
        }
    }
}

#Preview("Recent") {
    NavigationStack {
        BookShelfPage(
            shelf: .recent,
            sections: ListSection.byPeriod(Showcase.shelved, on: \.shelvedAt),
            statuses: [.toRead, .reading, .read],
            isLoading: false,
            errorMessage: nil,
            hasMore: false,
            loadMoreFailed: false
        ) { _ in }
    }
}

#Preview("Dropped") {
    NavigationStack {
        BookShelfPage(
            shelf: .dropped,
            sections: [ListSection(id: "all", title: "", rows: Array(Showcase.shelved.prefix(4)))],
            isLoading: false,
            errorMessage: nil,
            hasMore: false,
            loadMoreFailed: false
        ) { _ in }
    }
}
