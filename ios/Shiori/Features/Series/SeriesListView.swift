import SwiftUI

/// The Series tab: the sagas the reader follows, switched and filtered from the
/// toolbar exactly as the Library tab is — everything or the favourites,
/// sectioned by month — each row labelled with its state and drawn as a strip
/// of covers: the owned volumes with their reading status, and the published
/// ones the reader lacks dimmed between them.
///
/// The order comes from the server — the saga whose latest volume was shelved
/// most recently first — and the phone only cuts where the month changes. The
/// list is paginated, and ordered on the phone it would reshuffle every time a
/// page landed.
struct SeriesListView: View {
    /// Opens the add sheet, from the one button every empty state offers.
    var onScan: () -> Void = {}
    /// A view another tab asked this one to open on, taken and cleared as
    /// soon as the tab shows it.
    @Binding var requested: SeriesRequest?

    @State private var viewModel = SeriesListViewModel()
    /// The saga being opened. A button and a destination rather than a
    /// navigation link: the link draws a chevron on every row, and a list of
    /// sagas reads better as cards than as a menu.
    @State private var openSeries: SeriesDestination?

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
                            message: "Touchez le cœur d'une série pour la retrouver ici.",
                            primary: .init("Scanner un livre", systemImage: "camera") { onScan() }
                        )
                    } else if viewModel.stateFilter != nil {
                        EmptyStateView(
                            systemImage: viewModel.stateFilter?.symbol ?? "square.stack",
                            title: "Aucune série",
                            message: "Aucune de vos séries n'est dans cet état.",
                            primary: .init("Scanner un livre", systemImage: "camera") { onScan() }
                        )
                    } else {
                        EmptyStateView(
                            systemImage: "square.stack",
                            title: "Aucune série",
                            message: "Scannez un tome d'une saga et elle apparaîtra ici, avec tous ses volumes.",
                            primary: .init("Scanner un livre", systemImage: "camera") { onScan() }
                        )
                    }
                } else {
                    list
                }
            }
            .navigationTitle("Séries")
            .navigationSubtitle(viewModel.mode.subtitle)
            .toolbar { toolbar }
            // On the content rather than on the stack: the stack stays put
            // while a saga is pushed over it, the content comes back when the
            // saga is popped — and comes back changed, since a saga's first
            // opening is where the server builds its catalogue, which this
            // list draws as the missing covers of the strip. Over last
            // session's snapshot when the disk had one: the rows show at once
            // and the spinner at the top says they are being brought up to date.
            .task {
                takeRequested()
                await viewModel.loadOnAppear()
            }
        }
        .onChange(of: requested) { takeRequested() }
        // A heart given on a saga screen, a volume finished in the library: the
        // rows here say so the next time the reader looks, not the next launch.
        .onReceive(NotificationCenter.default.publisher(for: .shioriDataDidChange)) { _ in
            Task { await viewModel.load() }
        }
    }

    private func takeRequested() {
        guard let requested else { return }
        viewModel.show(requested)
        self.requested = nil
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
            ForEach(sections) { section in
                Section {
                    ForEach(section.rows) { entry in
                        // A tap rather than a button: a button would claim the
                        // drag that scrolls the cover strip and highlight the
                        // whole row on every swipe through it.
                        row(entry)
                            .contentShape(Rectangle())
                            .onTapGesture { openSeries = destination(of: entry) }
                            .accessibilityElement(children: .combine)
                            .accessibilityAddTraits(.isButton)
                            .accessibilityAction { openSeries = destination(of: entry) }
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
        .navigationDestination(item: $openSeries) {
            SeriesView(seriesId: $0.seriesId, language: $0.language)
        }
    }

    /// The saga in the edition of this row: a saga held in two languages makes
    /// two rows, and each must open on its own covers.
    private func destination(of entry: FollowedSeries) -> SeriesDestination {
        SeriesDestination(seriesId: entry.seriesId, language: entry.language)
    }

    /// The same controls as the Library tab: the two views on the left, the
    /// state filter beside them.
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup {
            ForEach(LibraryMode.seriesViews) { item in
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
                    // The saga set aside always last.
                    ForEach([SeriesState.inProgress, .notStarted, .complete, .unfollowed]) { state in
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

    /// The sagas cut into months, as the Library tab cuts its books, on the
    /// date the latest volume of each was shelved.
    private var sections: [MonthSection<FollowedSeries>] {
        MonthSection.cut(viewModel.followed, on: \.shelvedAt)
    }

    /// Every mark on the first line, in the top corner — the edition's
    /// language, where the reader stands, their heart or stars — so the eye
    /// finds them in the same place on every row; the covers underneath. The
    /// marks share that line only, as on the library rows: the author below
    /// takes the whole width instead of being squeezed beside them.
    private func row(_ entry: FollowedSeries) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 8) {
                    Text(entry.name).font(.body.weight(.medium)).lineLimit(2)
                    Spacer(minLength: 0)
                    marks(entry)
                }
                if let author = entry.author {
                    Text(author).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            covers(entry)
        }
        .padding(.vertical, 2)
    }

    private func marks(_ entry: FollowedSeries) -> some View {
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
        .fixedSize()
        .padding(.top, 3)
    }

    /// Every volume of the cycle, in its order, as a cover: the owned ones with
    /// their status pinned on, the missing ones dimmed with their number, the
    /// announced ones fainter still under a clock, the related works last — the
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
                    case let .missing(_, number, title, forthcoming):
                        BookCover(
                            book: Book(id: item.id, title: title, authors: entry.author.map { [$0] } ?? [], status: .toRead),
                            width: coverWidth,
                            showsFormatBadge: false
                        )
                        .opacity(forthcoming ? 0.2 : 0.35)
                        .overlay(alignment: .bottom) {
                            if let number {
                                Text(verbatim: "\(number)")
                                    .font(.caption2.weight(.bold).monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .padding(.bottom, 4)
                            }
                        }
                        // Where an owned volume pins its status: an announced
                        // one says it is not out yet.
                        .overlay(alignment: .topTrailing) {
                            if forthcoming {
                                Image(systemName: "clock")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                                    .padding(4)
                            }
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
        case .unfollowed: .secondary
        }
    }

    var body: some View {
        // A saga set aside says so by the crossed-out bell alone: the word
        // shouted a choice the reader already made.
        if state == .unfollowed {
            Image(systemName: state.symbol)
                .foregroundStyle(.secondary)
                .accessibilityLabel(Text(state.label))
        } else {
            label
        }
    }

    private var label: some View {
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
