import SwiftUI

/// "Livres", as Photos lays out a library: the covers alone, five by
/// row, edge to edge, under the month each was shelved in — the whole library
/// at a glance. No title: each cover's foot carries its stars, a white heart
/// for a favourite, and a tap opens the book. A menu in the toolbar narrows
/// the mosaic to one reading status, as the library's list once did.
struct BookMosaicPage: View {
    let sections: [ListSection<Book>]
    var formats: [BookFormat] = []
    var selectedFormat: BookFormat?
    var selectedStatus: ReadingStatus?
    let isLoading: Bool
    let errorMessage: String?
    let hasMore: Bool
    let loadMoreFailed: Bool
    let onAction: (BookShelfAction) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 5)

    /// The books given up on, in black and white and dimmed, as a poster
    /// draws one; their stars stay white.
    private var isShowingDropped: Bool { selectedStatus == .dropped }

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
                } else if sections.isEmpty, let selectedStatus {
                    EmptyState(
                        systemImage: selectedStatus.symbol,
                        title: "Aucun livre",
                        message: "Aucun livre de la bibliothèque n'a ce statut."
                    )
                    .padding(.top, 60)
                }
                ForEach(sections) { section in
                    Text(section.title)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 8)
                        .accessibilityAddTraits(.isHeader)
                        .transition(.opacity)
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
                                    .saturation(isShowingDropped ? 0 : 1)
                                    .overlay { if isShowingDropped { Color.black.opacity(PosterLabel.setAsideDimming) } }
                                }
                                .aspectRatio(2 / 3, contentMode: .fit)
                                .overlay(alignment: .bottom) { MosaicRating(book: book) }
                                .clipped()
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(book.title))
                            .bookContextMenu(book) { onAction(.menu(book, $0)) }
                            .onAppear { onAction(.reached(book.id)) }
                            .transition(.homeCard)
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
        .refreshable { onAction(.refresh) }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Statut", selection: Binding(
                        get: { selectedStatus },
                        set: { onAction(.selectStatus($0)) }
                    )) {
                        Label("Tous", systemImage: "tray.full").tag(ReadingStatus?.none)
                        // In the order a book lives through them, as a friend's library.
                        ForEach([ReadingStatus.reading, .toRead, .read, .dropped]) { status in
                            Label(status.shelfTitle, systemImage: status.symbol)
                                .tag(ReadingStatus?.some(status))
                        }
                    }
                } label: {
                    ShelfFilterLabel(
                        symbol: selectedStatus?.symbol ?? "tray.full",
                        title: selectedStatus?.shelfTitle ?? String(localized: "Tous")
                    )
                }
                .accessibilityIdentifier("all-books-status-filter")
            }
        }
    }
}

/// A cover's rating at its foot, in white on a blur of the cover: always five
/// stars, the ones not given as outlines, or a single heart for a favourite.
/// Nothing on a book not rated yet.
private struct MosaicRating: View {
    let book: Book

    var body: some View {
        if book.favorite || book.shownRating != nil {
            Group {
                if book.favorite {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                        .accessibilityLabel(Text("Coup de cœur"))
                } else if let rating = book.shownRating {
                    RatingStars(rating: rating, font: .system(size: 8), monochrome: true)
                }
            }
            .foregroundStyle(.white)
            .environment(\.colorScheme, .dark)
            .shadow(color: .black.opacity(0.45), radius: 2)
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
            .padding(.bottom, 4)
            .background(alignment: .bottom) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .mask(LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .center))
            }
        }
    }
}

#if DEBUG
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

#Preview("Dropped") {
    NavigationStack {
        BookMosaicPage(
            sections: ListSection.byMonth(Showcase.shelved.filter { $0.status == .dropped }, on: \.shelvedAt),
            selectedStatus: .dropped,
            isLoading: false,
            errorMessage: nil,
            hasMore: false,
            loadMoreFailed: false
        ) { _ in }
    }
}
#endif
