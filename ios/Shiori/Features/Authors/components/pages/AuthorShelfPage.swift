import SwiftUI

/// Everything the authors screen of the Library tab can ask for.
enum AuthorShelfAction {
    case openAuthor(FollowedAuthor)
    case openBook(Book)
    case order(AuthorListOrder)
    case menu(Book, BookQuickAction)
    case reached(String)
    case loadMore
    case refresh
}

/// The authors, as the TV app lists a filmography: a row per author — the
/// portrait and the name, opening their page — then their books as posters,
/// the line in each cover as everywhere: the stars, "Ajouté", the bookmark.
/// Ordered by the pills: the preferred first, the most recent, or A to Z.
struct AuthorShelfPage: View {
    let authors: [FollowedAuthor]
    let order: AuthorListOrder
    let isLoading: Bool
    let errorMessage: String?
    let hasMore: Bool
    let loadMoreFailed: Bool
    let onAction: (AuthorShelfAction) -> Void

    private static let orders: [AuthorListOrder] = [.loved, .recent, .name]

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
                ForEach(authors) { author in
                    row(author)
                        .onAppear { onAction(.reached(author.id)) }
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
        .navigationTitle("Auteurs")
        .refreshable { onAction(.refresh) }
        .overlay {
            if authors.isEmpty {
                if isLoading {
                    ProgressView()
                } else if let errorMessage {
                    EmptyState.failure("Auteurs indisponibles", message: errorMessage) { onAction(.refresh) }
                }
            }
        }
    }

    private func row(_ author: FollowedAuthor) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { onAction(.openAuthor(author)) } label: {
                HStack(spacing: 10) {
                    AuthorAvatar(initials: author.initials, portraitURL: author.portraitURL, size: 40)
                    Text(author.name)
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
            .accessibilityIdentifier("author-row")
            PosterRow(
                items: author.books.map { .init(book: $0, label: PosterLabel.of($0, in: .recent)) },
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

#Preview {
    NavigationStack {
        AuthorShelfPage(
            authors: Showcase.authorsPage(limit: 8, after: nil, order: .recent).items,
            order: .recent,
            isLoading: false,
            errorMessage: nil,
            hasMore: false,
            loadMoreFailed: false
        ) { _ in }
    }
}
