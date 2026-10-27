import SwiftUI

/// Everything a narrator's page can ask for.
enum NarratorAction {
    case openBook(Book)
    case openSeries(SeriesDestination)
    case menu(Book, BookQuickAction)
    case refresh
}

/// A narrator's page, drawn as an author's is: their round portrait over their
/// first cover blurred, the name, their figures, then the sagas heard in their
/// voice as the cards of "Toutes les séries" and their other recordings — each
/// opened to be rated, as anywhere else.
struct NarratorDetailPage: View {
    let name: String
    /// Nil until the server answered, or when the reader holds nothing of them.
    let page: NarratorPage?
    let isLoading: Bool
    let errorMessage: String?
    let onAction: (NarratorAction) async -> Void

    private static let portraitSize: CGFloat = 160
    /// Fewer and a second row would stand half empty.
    private static let twoRowsFrom = 6

    var body: some View {
        Group {
            if isLoading && page == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let page {
                content(page)
            } else {
                EmptyState.failure(
                    "Fiche indisponible",
                    message: errorMessage ?? String(localized: "Aucun livre audio de ce narrateur dans votre bibliothèque.")
                ) { await onAction(.refresh) }
            }
        }
        .background(Color(.systemGroupedBackground))
        // The name stays the page's title for the Back button's history, but
        // the bar does not show it: the hero says it, as on an author's page.
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(removing: .title)
        .refreshable { await onAction(.refresh) }
    }

    private func send(_ action: NarratorAction) {
        Task { await onAction(action) }
    }

    private func content(_ page: NarratorPage) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                hero(page)
                seriesSection(page)
                booksSection(page)
                if page.bookCount == 0 {
                    Text("Aucun de vos livres audio n'est lu par \(page.name).")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 32)
        }
        // The bar's buttons float over the portrait as it scrolls.
        .scrollEdgeEffectHidden(true, for: .top)
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Hero

    private func hero(_ page: NarratorPage) -> some View {
        VStack(spacing: 14) {
            AuthorAvatar(initials: page.initials, portraitURL: page.portraitURL, size: Self.portraitSize)
                .shadow(color: .black.opacity(0.4), radius: 18, y: 10)
                .padding(.top, 128)
            VStack(spacing: 4) {
                Text(page.name)
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                    .copyable(page.name)
                Label("Narration", systemImage: "waveform")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            if page.bookCount > 0 {
                figures(page)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            CoverBackdrop(url: page.backdropURL, fadeHeight: 240, ground: Color(.systemGroupedBackground))
                .frame(height: 600)
        }
    }

    /// The narrator's figures, spread across the width: listened, on the pile,
    /// the mean of the stars, the series.
    private func figures(_ page: NarratorPage) -> some View {
        let held = page.books + page.sagas.flatMap(\.volumes)
        let pile = held.filter { $0.status == .toRead }.count
        var items: [(value: String, label: String)] = [
            (page.readCount.formatted(), String(localized: "écoutés")),
            (pile.formatted(), String(localized: "à écouter")),
        ]
        if let rating = page.averageRating {
            items.append(("★ \(rating.formatted(.number.precision(.fractionLength(1))))", String(localized: "moyenne")))
        }
        let series = page.seriesCount
        items.append((series.formatted(), series > 1 ? String(localized: "séries") : String(localized: "série")))
        return HStack(alignment: .top) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(spacing: 2) {
                    Text(item.value)
                        .font(.headline)
                    Text(item.label.localizedUppercase)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Sections

    @ViewBuilder
    private func seriesSection(_ page: NarratorPage) -> some View {
        if !page.sagas.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                RowHeader(title: "Séries", style: .inline).padding(.horizontal, 20)
                SeriesCardRail(series: page.sagas) { saga in
                    send(.openSeries(SeriesDestination(seriesId: saga.seriesId)))
                }
            }
        }
    }

    @ViewBuilder
    private func booksSection(_ page: NarratorPage) -> some View {
        if !page.books.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                RowHeader(title: "Livres", style: .inline).padding(.horizontal, 20)
                PosterRow(
                    items: page.books.map { .init(book: $0, label: PosterLabel.of($0, in: .recent)) },
                    rows: page.books.count >= Self.twoRowsFrom ? 2 : 1,
                    onOpen: { send(.openBook($0)) },
                    onMenu: { book, action in send(.menu(book, action)) }
                )
                .contentMargins(.horizontal, 20, for: .scrollContent)
            }
        }
    }
}

#Preview {
    NavigationStack {
        NarratorDetailPage(name: "Bernard Gabay", page: .preview, isLoading: false, errorMessage: nil) { _ in }
    }
}

#Preview("Holds nothing of them") {
    NavigationStack {
        NarratorDetailPage(name: "Bernard Gabay", page: nil, isLoading: false, errorMessage: nil) { _ in }
    }
}
