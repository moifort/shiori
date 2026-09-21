import SwiftUI

/// The Series tab: the sagas the reader follows, in one section per genre, each
/// row saying how far along the reader is.
///
/// The sections come from the server's order — the list is paginated, and a
/// section grouped on the phone would grow again every time a page landed.
///
/// A saga nobody has catalogued has no spine to measure against: what it has
/// instead is how many volumes are on the shelf. That is a fact about the
/// library, not a score out of a total nobody knows.
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
            ForEach(sections, id: \.id) { section in
                Section {
                    ForEach(section.entries) { entry in
                        Button {
                            openSeriesId = entry.seriesId
                        } label: {
                            row(entry)
                        }
                        .tint(.primary)
                        .accessibilityIdentifier("series-row")
                        .onAppear { viewModel.prefetchIfNeeded(for: entry.id) }
                    }
                } header: {
                    if let genre = section.genre {
                        Label { Text(genre.label) } icon: { genre.image }
                    } else {
                        Text("Sans genre")
                    }
                }
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

    /// Consecutive rows of one genre, as the server ordered them. Grouped on
    /// runs rather than on the genre itself, so a page that lands never moves a
    /// row the reader has already scrolled past.
    private var sections: [(id: Int, genre: BookGenre?, entries: [FollowedSeries])] {
        var sections: [(id: Int, genre: BookGenre?, entries: [FollowedSeries])] = []
        for entry in viewModel.followed {
            if let last = sections.last, last.genre == entry.genre {
                sections[sections.count - 1].entries.append(entry)
            } else {
                sections.append((id: sections.count, genre: entry.genre, entries: [entry]))
            }
        }
        return sections
    }

    /// The same shape as a library row: the words on the left, and every mark
    /// on one line in the top corner — the edition's language, the saga's
    /// state, the reader's heart or stars — so the eye finds them in the same
    /// place on every row.
    private func row(_ entry: FollowedSeries) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name).font(.body.weight(.medium))
                if let author = entry.author {
                    Text(author).font(.subheadline).foregroundStyle(.secondary)
                }
                standing(entry).padding(.top, 2)
            }
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                if let language = entry.language, language.isForeign {
                    LanguageTag(language: language)
                }
                if let state = entry.state {
                    SeriesStateBadge(state: state)
                }
                OpinionMark(
                    rating: entry.opinion?.rating,
                    isFavorite: entry.opinion?.favorite == true,
                    font: .caption
                )
            }
            .font(.caption)
            .padding(.top, 3)
        }
        .padding(.vertical, 2)
    }

    /// Where the reader is in the saga: a bar and "3 / 14" when the catalogue
    /// says how many volumes are out, how many sit on the shelf otherwise.
    @ViewBuilder
    private func standing(_ entry: FollowedSeries) -> some View {
        if let progress = entry.progress {
            HStack(spacing: 8) {
                ProgressView(value: Double(progress.read), total: Double(progress.total))
                    .tint(progress.read == progress.total ? .green : .accentColor)
                Text(verbatim: "\(progress.read) / \(progress.total)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(progress.read) tomes lus sur \(progress.total) parus"))
        } else {
            Label("\(entry.ownedCount) tome(s)", systemImage: "books.vertical")
                .labelStyle(.caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// Whether a saga is still going or done, as one glyph in a row's corner: a
/// tick once every published volume is read, an open book until then. In the
/// row's secondary grey rather than in colour — the glyph is a fact to read,
/// and next to the stars and the heart a green and a blue would compete with
/// the reader's own judgement. Icon-only, so the state is spoken.
struct SeriesStateBadge: View {
    let state: SeriesState

    var body: some View {
        Image(systemName: state == .complete ? "checkmark.circle.fill" : "book.fill")
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityLabel(Text(state.label))
    }
}
