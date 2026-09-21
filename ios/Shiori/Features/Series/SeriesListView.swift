import SwiftUI

/// The Series tab: the sagas the reader follows, each in progress or complete.
///
/// No counter. "2 sur 14" reads as a scoreboard on a list whose purpose is to
/// let the reader pick a saga and get back into it — the state is what tells
/// them whether there is anything left to read.
///
/// A saga nobody has catalogued has no state to show: what it has instead is
/// how many volumes are on the shelf. That is a fact about the library, not a
/// score out of a total nobody knows.
struct SeriesListView: View {
    @State private var viewModel = SeriesListViewModel()
    /// The saga being opened. A button and a destination rather than a
    /// navigation link: the link draws a chevron on every row, and a list of
    /// sagas reads better as cards than as a menu.
    @State private var openSeriesId: String?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.followed.isEmpty {
                    ProgressView("Chargement de vos séries...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage, viewModel.followed.isEmpty {
                    ContentUnavailableView {
                        Label("Séries indisponibles", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        AsyncButton("Réessayer") { await viewModel.load() }
                    }
                } else if viewModel.followed.isEmpty {
                    ContentUnavailableView {
                        Label("Aucune série", systemImage: "square.stack")
                    } description: {
                        Text("Scannez un tome d'une saga et elle apparaîtra ici, avec tous ses volumes.")
                    }
                } else {
                    list
                }
            }
            .navigationTitle("Séries")
        }
        // Over last session's snapshot when the disk had one: the rows show at
        // once and the spinner at the top says they are being brought up to date.
        .task { await viewModel.loadOnAppear() }
        // A heart given on a saga screen, a volume finished in the library: the
        // rows here say so the next time the reader looks, not the next launch.
        .onReceive(NotificationCenter.default.publisher(for: .shioriDataDidChange)) { _ in
            Task { await viewModel.load() }
        }
    }

    private var list: some View {
        List {
            // Leads the rows it is refreshing, never replaces them.
            if viewModel.isRefreshing || viewModel.refreshFailed {
                RefreshRow(
                    failed: viewModel.refreshFailed,
                    loadingLabel: "Mise à jour des séries",
                    onRetry: { await viewModel.refresh() }
                )
            }
            ForEach(viewModel.followed) { entry in
                Button {
                    openSeriesId = entry.seriesId
                } label: {
                    row(entry)
                }
                .tint(.primary)
                .accessibilityIdentifier("series-row")
                .onAppear { viewModel.prefetchIfNeeded(for: entry.id) }
            }
            if viewModel.hasMore {
                LoadMoreRow(
                    failed: viewModel.loadMoreFailed,
                    loadingLabel: "Chargement de la suite",
                    onLoadMore: { await viewModel.loadMore() }
                )
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await viewModel.load() }
        .navigationDestination(item: $openSeriesId) { SeriesView(seriesId: $0) }
    }

    /// The same shape as a library row: the words on the left, and on the
    /// right, level with the name, what the reader should know at a glance —
    /// the saga's state as one glyph, then their own heart or stars beneath.
    private func row(_ entry: FollowedSeries) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.name).font(.body.weight(.medium))
                    // Which of the saga's two shelves this row is. Trailing
                    // the name, as in the library headings: the name is what
                    // the reader scans for, and only foreign, as there too.
                    if let language = entry.language, language.isForeign {
                        Text(language.flag).accessibilityLabel(Text(language.label))
                    }
                }
                if let author = entry.author {
                    Text(author).font(.subheadline).foregroundStyle(.secondary)
                }
                // How much of the saga is on the shelf. A saga with a state
                // says it in the corner; one nobody has catalogued has only
                // this count to show.
                Label("\(entry.ownedCount) tome(s)", systemImage: "books.vertical")
                    .labelStyle(.caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                if let state = entry.state {
                    SeriesStateBadge(state: state)
                }
                OpinionMark(
                    rating: entry.opinion?.rating,
                    isFavorite: entry.opinion?.favorite == true,
                    font: .caption
                )
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 2)
    }

}

/// Whether a saga is still going or done, as one glyph in a row's corner: the
/// tick in green once every published volume is read, an open book until then.
/// Icon-only, because the corner has no room for a word; the state is spoken.
struct SeriesStateBadge: View {
    let state: SeriesState

    var body: some View {
        Image(systemName: state == .complete ? "checkmark.circle.fill" : "book.fill")
            .font(.caption)
            .foregroundStyle(state == .complete ? Color.green : Color.blue)
            .accessibilityLabel(Text(state.label))
    }
}
