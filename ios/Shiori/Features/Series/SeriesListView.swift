import SwiftUI

/// The Series tab: the sagas the reader follows, in one section per genre, each
/// row labelled with where the reader stands and drawn as a strip of the owned
/// volumes' covers, each carrying its reading status.
///
/// The sections and their order come from the server — within a genre, what
/// the reader is on first, then what they finished, then what they have not
/// opened, the latest status change leading each. The list is paginated, and a
/// section grouped on the phone would grow again every time a page landed.
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
                        // A tap rather than a button: a button would claim the
                        // drag that scrolls the cover strip and highlight the
                        // whole row on every swipe through it.
                        row(entry)
                            .contentShape(Rectangle())
                            .onTapGesture { openSeriesId = entry.seriesId }
                            .accessibilityElement(children: .combine)
                            .accessibilityAddTraits(.isButton)
                            .accessibilityAction { openSeriesId = entry.seriesId }
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

    /// The words on the left and every mark on one line in the top corner —
    /// the edition's language, where the reader stands, their heart or stars —
    /// so the eye finds them in the same place on every row; the covers
    /// underneath.
    private func row(_ entry: FollowedSeries) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.name).font(.body.weight(.medium))
                    if let author = entry.author {
                        Text(author).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    if let language = entry.language, language.isForeign {
                        LanguageTag(language: language)
                    }
                    if let state = entry.state {
                        SeriesStateLabel(state: state)
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
            covers(entry)
        }
        .padding(.vertical, 2)
    }

    /// Every owned volume, in the order the saga runs, as a cover with its
    /// status pinned on — the reader's progress read off the books themselves
    /// rather than off a bar. No titles: the covers say which book is which,
    /// and the saga screen is a tap away.
    private func covers(_ entry: FollowedSeries) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 10) {
                ForEach(entry.volumes) { volume in
                    BookCover(book: volume, width: coverWidth)
                        .overlay(alignment: .topTrailing) {
                            ReadingStatusBadge(status: volume.status)
                                .offset(x: 5, y: -5)
                        }
                }
            }
            // Room for the badges, which overhang the covers' corners and the
            // scroll view would otherwise clip.
            .padding(.top, 6)
            .padding(.trailing, 6)
        }
        .scrollIndicators(.hidden)
        .accessibilityHidden(true)
    }

    private let coverWidth: CGFloat = 44
}

/// Where the reader stands on a saga, in words — "En cours", "Terminée",
/// "À lire" — as a small tag in the colour of the reading-status badge it
/// matches: blue for reading, green for read, grey for the pile.
struct SeriesStateLabel: View {
    let state: SeriesState

    private var tint: Color {
        switch state {
        case .notStarted: .gray
        case .inProgress: .blue
        case .complete: .green
        }
    }

    var body: some View {
        Text(state.label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.opacity(0.15), in: Capsule())
            .fixedSize()
    }
}

#Preview {
    HStack {
        SeriesStateLabel(state: .inProgress)
        SeriesStateLabel(state: .complete)
        SeriesStateLabel(state: .notStarted)
    }
    .padding()
}
