import SwiftUI

/// Everything a shelf of people — the authors, the narrators — can ask for.
enum PersonShelfAction<Person: ShelvedPerson> {
    case openPerson(Person)
    case openBook(Book)
    case order(AuthorListOrder)
    case menu(Book, BookQuickAction)
    case reached(String)
    case loadMore
    case refresh
}

/// The authors, or the narrators, as the TV app lists a filmography: a row per
/// person — the portrait and the name, opening their page — then their books
/// as posters, the line in each cover as everywhere: the stars, "Ajouté", the
/// bookmark. Ordered by the pills: the preferred first, the most recent, or A
/// to Z.
struct PersonShelfPage<Person: ShelvedPerson>: View {
    let title: LocalizedStringKey
    let failureTitle: LocalizedStringKey
    /// What UI tests find each row by.
    let rowIdentifier: String
    let people: [Person]
    let order: AuthorListOrder
    let isLoading: Bool
    let errorMessage: String?
    let hasMore: Bool
    let loadMoreFailed: Bool
    let onAction: (PersonShelfAction<Person>) -> Void

    private static var orders: [AuthorListOrder] { [.loved, .recent, .name] }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 26) {
                FilterPills(
                    pills: Self.orders.map { FilterPills.Pill(id: $0.rawValue, label: $0.pillLabel) },
                    selected: order.rawValue,
                    allLabel: nil
                ) { id in
                    if let order = id.flatMap(AuthorListOrder.init(rawValue:)) { onAction(.order(order)) }
                }
                ForEach(people) { person in
                    row(person)
                        .onAppear { onAction(.reached(person.id)) }
                }
                if hasMore {
                    LoadMoreRow(
                        failed: loadMoreFailed,
                        loadingLabel: "Chargement de la suite",
                        onLoadMore: { onAction(.loadMore) }
                    )
                }
            }
            .padding(.vertical, 8)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(title)
        .refreshable { onAction(.refresh) }
        .overlay {
            if people.isEmpty {
                if isLoading {
                    ProgressView()
                } else if let errorMessage {
                    EmptyState.failure(failureTitle, message: errorMessage) { onAction(.refresh) }
                }
            }
        }
    }

    private func row(_ person: Person) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { onAction(.openPerson(person)) } label: {
                HStack(spacing: 10) {
                    AuthorAvatar(initials: person.initials, portraitURL: person.portraitURL, size: 40)
                    Text(person.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .accessibilityIdentifier(rowIdentifier)
            PosterRow(
                items: person.books.map { .init(book: $0, label: PosterLabel.of($0, in: .recent)) },
                onOpen: { onAction(.openBook($0)) },
                onMenu: { onAction(.menu($0, $1)) }
            )
            .contentMargins(.horizontal, 20, for: .scrollContent)
        }
    }
}

extension AuthorListOrder {
    /// The pill that orders the authors this way.
    var pillLabel: String {
        switch self {
        case .loved: String(localized: "Préférés")
        case .recent: String(localized: "Récents")
        case .name: String(localized: "A–Z")
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        PersonShelfPage(
            title: "Auteurs",
            failureTitle: "Auteurs indisponibles",
            rowIdentifier: "author-row",
            people: Showcase.authorsPage(limit: 8, after: nil, order: .recent).items,
            order: .recent,
            isLoading: false,
            errorMessage: nil,
            hasMore: false,
            loadMoreFailed: false
        ) { _ in }
    }
}

#Preview("Narrateurs") {
    NavigationStack {
        PersonShelfPage(
            title: "Narrateurs",
            failureTitle: "Narrateurs indisponibles",
            rowIdentifier: "narrator-row",
            people: Showcase.narratorsPage(limit: 8, after: nil, order: .recent).items,
            order: .recent,
            isLoading: false,
            errorMessage: nil,
            hasMore: false,
            loadMoreFailed: false
        ) { _ in }
    }
}
#endif
