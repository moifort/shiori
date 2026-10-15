import SwiftUI

/// Everything the Authors shelf can ask for.
enum AuthorListAction {
    case open(FollowedAuthor)
    case order(AuthorListOrder)
    /// A row came into sight: the next page may be due.
    case reached(String)
    case loadMore
    case refresh
    case scan
}

/// The Authors shelf of the Library tab: every author the reader holds a book
/// of, listed two ways from the toolbar. By name, as the Contacts app lists
/// people: a section per letter of their surname and the alphabet down the
/// side to jump to one. By activity, as the Books and Series shelves are: the
/// author whose newest book was shelved most recently first, cut into months.
/// Or the ones they love first — most hearts, then the best stars, then the
/// most books.
///
/// Every order comes from the server, which files an author under their
/// surname the way a bookshop does; the phone only cuts the sections.
///
struct AuthorListPage: View {
    let authors: [FollowedAuthor]
    let order: AuthorListOrder
    let isLoading: Bool
    let errorMessage: String?
    let hasMore: Bool
    let loadMoreFailed: Bool
    let onAction: (AuthorListAction) async -> Void

    var body: some View {
        Group {
            if isLoading && authors.isEmpty {
                ProgressView("Chargement de vos auteurs...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = errorMessage, authors.isEmpty {
                EmptyStateView.failure("Auteurs indisponibles", message: errorMessage) {
                    await onAction(.refresh)
                }
            } else if authors.isEmpty {
                EmptyStateView(
                    systemImage: "person.2",
                    title: "Aucun auteur",
                    message: "Scannez un livre et son auteur apparaîtra ici, avec tous ses livres.",
                    primary: .init("Scanner un livre", systemImage: "camera") { Task { await onAction(.scan) } }
                )
            } else {
                list
            }
        }
        .navigationTitle("Auteurs")
        .navigationSubtitle(order.subtitle)
        .toolbar { toolbar }
    }

    private var list: some View {
        List {
            switch order {
            case .name:
                ForEach(letters, id: \.letter) { section in
                    Section(section.letter) {
                        ForEach(section.authors) { author in row(author) }
                    }
                    .sectionIndexLabel(section.letter)
                }
            case .recent:
                ForEach(MonthSection.cut(authors, on: \.shelvedAt)) { section in
                    Section(section.title) {
                        ForEach(section.rows) { author in row(author) }
                    }
                }
            case .loved:
                Section {
                    ForEach(authors) { author in row(author) }
                }
            }
            if hasMore {
                LoadMoreRow(
                    failed: loadMoreFailed,
                    loadingLabel: "Chargement de la suite",
                    onLoadMore: { await onAction(.loadMore) }
                )
            }
        }
        .listStyle(.insetGrouped)
        .listSectionIndexVisibility(order == .name ? .visible : .hidden)
        .refreshable { await onAction(.refresh) }
    }

    private func row(_ author: FollowedAuthor) -> some View {
        AuthorRow(author: author)
            .contentShape(Rectangle())
            .onTapGesture { Task { await onAction(.open(author)) } }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { Task { await onAction(.open(author)) } }
            .edgeToEdgeSeparator()
            .accessibilityIdentifier("author-row")
            .onAppear { Task { await onAction(.reached(author.id)) } }
    }

    /// The authors cut where the letter they are filed under changes. The
    /// server already hands them over in that order, "#" last.
    private var letters: [(letter: String, authors: [FollowedAuthor])] {
        var sections: [(letter: String, authors: [FollowedAuthor])] = []
        for author in authors {
            if sections.last?.letter == author.indexLetter {
                sections[sections.count - 1].authors.append(author)
            } else {
                sections.append((author.indexLetter, [author]))
            }
        }
        return sections
    }

    /// The orders, as the Books and Series shelves offer their views.
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup {
            ForEach(AuthorListOrder.allCases) { item in
                Button {
                    Task { await onAction(.order(item)) }
                } label: {
                    Label(item.label, systemImage: item.icon)
                }
                .labelStyle(.iconOnly)
                .tint(order == item ? .accentColor : .primary)
                .accessibilityIdentifier("authors-order-\(item.rawValue)")
            }
        }
    }
}

#Preview {
    NavigationStack {
        AuthorListPage(
            authors: FollowedAuthor.previews, order: .recent, isLoading: false, errorMessage: nil,
            hasMore: false, loadMoreFailed: false
        ) { _ in }
    }
}
