import SwiftUI

/// "Tous les livres", as Photos lays out a library: the covers alone, five by
/// row, edge to edge, under the month each was shelved in — the whole library
/// at a glance. No label: a tap opens the book.
struct BookMosaicPage: View {
    let sections: [ListSection<Book>]
    var formats: [BookFormat] = []
    var selectedFormat: BookFormat?
    let isLoading: Bool
    let errorMessage: String?
    let hasMore: Bool
    let loadMoreFailed: Bool
    let onAction: (BookShelfAction) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 5)

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if formats.count > 1 {
                    FilterPills(
                        pills: formats.map { FilterPills.Pill(id: $0.rawValue, label: $0.shelfLabel) },
                        selected: selectedFormat?.rawValue
                    ) { onAction(.selectFormat($0.flatMap(BookFormat.init(rawValue:)))) }
                    .padding(.bottom, 8)
                }
                if sections.isEmpty, isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
                } else if sections.isEmpty, let errorMessage {
                    EmptyState.failure("Bibliothèque indisponible", message: errorMessage) { onAction(.refresh) }
                        .padding(.top, 60)
                }
                ForEach(sections) { section in
                    Text(section.title)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 8)
                        .accessibilityAddTraits(.isHeader)
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(section.rows) { book in
                            Button { onAction(.openBook(book)) } label: {
                                GeometryReader { proxy in
                                    BookCover(
                                        book: book,
                                        width: proxy.size.width,
                                        showsFormatBadge: false,
                                        cornerRadius: 0
                                    )
                                }
                                .aspectRatio(2 / 3, contentMode: .fit)
                                .clipped()
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(book.title))
                            .bookContextMenu(book) { onAction(.menu(book, $0)) }
                            .onAppear { onAction(.reached(book.id)) }
                        }
                    }
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
        .navigationTitle(BookShelf.all.title)
        .navigationBarTitleDisplayMode(.large)
        .refreshable { onAction(.refresh) }
    }
}

#Preview {
    NavigationStack {
        BookMosaicPage(
            sections: ListSection.byMonth(Showcase.shelved, on: \.shelvedAt),
            formats: [.book, .manga],
            isLoading: false,
            errorMessage: nil,
            hasMore: false,
            loadMoreFailed: false
        ) { _ in }
    }
}
