import SwiftUI

/// The Series tab: the sagas the reader follows, switched and filtered from the
/// toolbar exactly as the Library tab is — everything or the favourites
/// sectioned by where the reader stands, or one section per genre — each row
/// labelled with its state and drawn as a strip of covers: the owned volumes
/// with their reading status, and the published ones the reader lacks dimmed
/// between them.
///
/// The sections and their order come from the server — what the reader is on
/// first, then what they finished, then what they have not opened, the latest
/// status change leading each. The list is paginated, and a section grouped on
/// the phone would grow again every time a page landed.
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
                    EmptyStateView.failure("Séries indisponibles", message: errorMessage) {
                        await viewModel.load()
                    }
                } else if viewModel.followed.isEmpty {
                    if viewModel.mode == .favorites {
                        EmptyStateView(
                            systemImage: "heart",
                            title: "Aucune série favorite",
                            message: "Touchez le cœur d'une série pour la retrouver ici."
                        )
                    } else if viewModel.stateFilter != nil {
                        EmptyStateView(
                            systemImage: viewModel.stateFilter?.symbol ?? "square.stack",
                            title: "Aucune série",
                            message: "Aucune de vos séries n'est dans cet état.",
                            primary: .init("Voir toutes les séries", systemImage: "tray.full") {
                                viewModel.stateFilter = nil
                            }
                        )
                    } else {
                        EmptyStateView(
                            systemImage: "square.stack",
                            title: "Aucune série",
                            message: "Scannez un tome d'une saga et elle apparaîtra ici, avec tous ses volumes."
                        )
                    }
                } else {
                    list
                }
            }
            .navigationTitle("Séries")
            .navigationSubtitle(viewModel.mode.subtitle)
            .toolbar { toolbar }
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
                    Text(section.title)
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

    /// The same controls as the Library tab: the three views on the left, the
    /// state filter beside them.
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup {
            ForEach(LibraryMode.allCases) { item in
                Button {
                    viewModel.mode = item
                } label: {
                    Label(item.label, systemImage: item.icon)
                }
                .labelStyle(.iconOnly)
                .tint(viewModel.mode == item ? .accentColor : .primary)
                .accessibilityIdentifier("series-mode-\(item.rawValue)")
            }
        }
        ToolbarSpacer(.fixed)
        ToolbarItemGroup {
            Menu {
                Picker("État", selection: $viewModel.stateFilter) {
                    Label("Toutes", systemImage: "tray.full").tag(SeriesState?.none)
                    ForEach([SeriesState.inProgress, .notStarted, .complete]) { state in
                        Label(state.shelfTitle, systemImage: state.symbol)
                            .tag(SeriesState?.some(state))
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .symbolVariant(viewModel.stateFilter != nil ? .fill : .none)
            }
            .accessibilityIdentifier("series-filter-menu")
        }
    }

    /// What a section is keyed on: the genre in the genre view, where the
    /// reader stands everywhere else.
    private enum SectionKey: Equatable {
        case genre(BookGenre?)
        case state(SeriesState?)
    }

    /// Consecutive rows of one key, as the server ordered them. Grouped on runs
    /// rather than on the key itself, so a page that lands never moves a row
    /// the reader has already scrolled past.
    private var sections: [(id: Int, title: String, entries: [FollowedSeries])] {
        var sections: [(id: Int, key: SectionKey, entries: [FollowedSeries])] = []
        for entry in viewModel.followed {
            let key: SectionKey = viewModel.mode == .genre ? .genre(entry.genre) : .state(entry.state)
            if let last = sections.last, last.key == key {
                sections[sections.count - 1].entries.append(entry)
            } else {
                sections.append((id: sections.count, key: key, entries: [entry]))
            }
        }
        return sections.map { (id: $0.id, title: title(of: $0.key), entries: $0.entries) }
    }

    private func title(of key: SectionKey) -> String {
        switch key {
        case let .genre(genre): genre?.label ?? String(localized: "Sans genre")
        // Every owned volume read and no catalogue to say more: finished as
        // far as the shelf goes.
        case let .state(state): state?.shelfTitle ?? String(localized: "Lues")
        }
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

    /// Every volume of the cycle, in its order, as a cover: the owned ones with
    /// their status pinned on, the missing ones dimmed with their number — the
    /// reader's progress, and what they lack, read off the books themselves
    /// rather than off a bar. No titles: the saga screen is a tap away.
    private func covers(_ entry: FollowedSeries) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 10) {
                ForEach(entry.strip.isEmpty ? entry.volumes.map { SeriesStripItem.owned($0) } : entry.strip) { item in
                    switch item {
                    case let .owned(volume):
                        BookCover(book: volume, width: coverWidth, showsFormatBadge: false)
                            .overlay(alignment: .topTrailing) {
                                ReadingStatusBadge(status: volume.status)
                                    .offset(x: 5, y: -5)
                            }
                    case let .missing(number, title):
                        BookCover(
                            book: Book(id: item.id, title: title, authors: entry.author.map { [$0] } ?? [], status: .toRead),
                            width: coverWidth,
                            showsFormatBadge: false
                        )
                        .opacity(0.35)
                        .overlay(alignment: .bottom) {
                            Text(verbatim: "\(number)")
                                .font(.caption2.weight(.bold).monospacedDigit())
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 4)
                        }
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
