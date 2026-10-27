import SwiftUI

/// Everything "Toute la pile" can ask for.
enum WholePileAction {
    case openBook(Book)
    case selectGrouping(PileGrouping)
    case menu(Book, BookQuickAction)
    case refresh
}

/// "Toute la pile": every book of the pile, three posters a row, under the
/// headings the pills choose — how long they have waited, their format or
/// their genre. Each cover says what its heading does not.
struct WholePilePage: View {
    let sections: [ListSection<Book>]
    let grouping: PileGrouping
    let label: (Book) -> PosterLabel
    let isLoading: Bool
    let errorMessage: String?
    let onAction: (WholePileAction) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 13), count: 3)

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                FilterPills(
                    pills: PileGrouping.allCases.map { FilterPills.Pill(id: $0.rawValue, label: $0.label) },
                    selected: grouping.rawValue,
                    allLabel: nil
                ) { id in
                    if let grouping = id.flatMap(PileGrouping.init(rawValue:)) { onAction(.selectGrouping(grouping)) }
                }
                .padding(.bottom, 4)
                if sections.isEmpty { empty }
                ForEach(sections) { section in
                    Text(section.title)
                        .font(.title2.weight(.bold))
                        .padding(.horizontal, 20)
                        .padding(.top, 22)
                        .padding(.bottom, 12)
                        .accessibilityAddTraits(.isHeader)
                    LazyVGrid(columns: columns, spacing: 13) {
                        ForEach(section.rows) { book in
                            poster(book)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(String(localized: "Toute la pile"))
        .refreshable { onAction(.refresh) }
    }

    private func poster(_ book: Book) -> some View {
        let label = label(book)
        return Button { onAction(.openBook(book)) } label: {
            GeometryReader { proxy in
                PosterCover(book: book, label: label, width: proxy.size.width)
            }
            .aspectRatio(2 / 3, contentMode: .fit)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(book.title), \(label.caption)"))
        .bookContextMenu(book) { onAction(.menu(book, $0)) }
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
            EmptyState(systemImage: "books.vertical", title: "Pile vide", message: "Les livres à lire s'afficheront ici.")
                .padding(.top, 60)
        }
    }
}

#if DEBUG
#Preview("By date") {
    let pile = Showcase.shelved.filter { $0.status == .toRead }
    NavigationStack {
        WholePilePage(
            sections: WholePile.sections(pile, by: .date),
            grouping: .date,
            label: { WholePile.label(of: $0, by: .date) },
            isLoading: false,
            errorMessage: nil
        ) { _ in }
    }
}

#Preview("By genre") {
    let pile = Showcase.shelved.filter { $0.status == .toRead }
    NavigationStack {
        WholePilePage(
            sections: WholePile.sections(pile, by: .genre),
            grouping: .genre,
            label: { WholePile.label(of: $0, by: .genre) },
            isLoading: false,
            errorMessage: nil
        ) { _ in }
    }
}
#endif
