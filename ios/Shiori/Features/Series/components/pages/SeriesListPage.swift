import SwiftUI

/// Everything the Series tab's page can ask for.
enum SeriesListAction {
    case open(FollowedSeries)
    /// A row came into sight: the next page may be due.
    case reached(String)
    case loadMore
    case refresh
    case scan
}

/// The Series tab, drawn: the sagas the reader follows, switched and filtered
/// from the toolbar exactly as the Library tab is — everything or the
/// favourites, sectioned by month — each row labelled with its state and drawn
/// as a strip of covers.
///
/// The order comes from the server — the saga whose latest volume was shelved
/// most recently first — and the phone only cuts where the month changes.
struct SeriesListPage: View {
    let followed: [FollowedSeries]
    @Binding var mode: LibraryMode
    @Binding var stateFilter: SeriesState?
    let isLoading: Bool
    let errorMessage: String?
    let hasMore: Bool
    let loadMoreFailed: Bool
    let onAction: (SeriesListAction) async -> Void

    var body: some View {
        Group {
            if isLoading && followed.isEmpty {
                ProgressView("Chargement de vos séries...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = errorMessage, followed.isEmpty {
                EmptyState.failure("Séries indisponibles", message: errorMessage) {
                    await onAction(.refresh)
                }
            } else if followed.isEmpty {
                if mode == .favorites {
                    EmptyState(
                        systemImage: "heart",
                        title: "Aucune série favorite",
                        message: "Touchez le cœur d'une série pour la retrouver ici.",
                        primary: .init("Scanner un livre", systemImage: "camera") { Task { await onAction(.scan) } }
                    )
                } else if stateFilter != nil {
                    EmptyState(
                        systemImage: stateFilter?.symbol ?? "square.stack",
                        title: "Aucune série",
                        message: "Aucune de vos séries n'est dans cet état.",
                        primary: .init("Scanner un livre", systemImage: "camera") { Task { await onAction(.scan) } }
                    )
                } else {
                    EmptyState(
                        systemImage: "square.stack",
                        title: "Aucune série",
                        message: "Scannez un tome d'une saga et elle apparaîtra ici, avec tous ses volumes.",
                        primary: .init("Scanner un livre", systemImage: "camera") { Task { await onAction(.scan) } }
                    )
                }
            } else {
                list
            }
        }
        .navigationTitle("Séries")
        .navigationSubtitle(mode.subtitle)
        .toolbar { toolbar }
    }

    private var list: some View {
        List {
            ForEach(sections) { section in
                Section {
                    ForEach(section.rows) { entry in
                        // A tap rather than a button: a button would claim the
                        // drag that scrolls the cover strip and highlight the
                        // whole row on every swipe through it.
                        SeriesRow(entry: entry)
                            .contentShape(Rectangle())
                            .onTapGesture { Task { await onAction(.open(entry)) } }
                            .accessibilityElement(children: .combine)
                            .accessibilityAddTraits(.isButton)
                            .accessibilityAction { Task { await onAction(.open(entry)) } }
                            .edgeToEdgeSeparator()
                            .accessibilityIdentifier("series-row")
                            .onAppear { Task { await onAction(.reached(entry.id)) } }
                    }
                } header: {
                    Text(section.title)
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
        .refreshable { await onAction(.refresh) }
    }

    /// The same controls as the Library tab: the two views on the left, the
    /// state filter beside them.
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup {
            ForEach(LibraryMode.seriesViews) { item in
                Button {
                    mode = item
                } label: {
                    Label(item.label, systemImage: item.icon)
                }
                .labelStyle(.iconOnly)
                .tint(mode == item ? .accentColor : .primary)
                .accessibilityIdentifier("series-mode-\(item.rawValue)")
            }
        }
        ToolbarSpacer(.fixed)
        ToolbarItemGroup {
            Menu {
                Picker("État", selection: $stateFilter) {
                    Label("Toutes", systemImage: "tray.full").tag(SeriesState?.none)
                    // The saga set aside always last.
                    ForEach([SeriesState.inProgress, .notStarted, .complete, .unfollowed]) { state in
                        Label(state.shelfTitle, systemImage: state.symbol)
                            .tag(SeriesState?.some(state))
                    }
                }
            } label: {
                ShelfFilterLabel(
                    symbol: stateFilter?.symbol ?? "tray.full",
                    title: stateFilter?.shelfTitle ?? String(localized: "Toutes")
                )
            }
            .accessibilityIdentifier("series-filter-menu")
        }
    }

    /// The sagas cut into months, as the Library tab cuts its books, on the
    /// date the latest volume of each was shelved — or, under the favourites,
    /// into the hearts and then each count of stars, as the server ranked them.
    private var sections: [ListSection<FollowedSeries>] {
        mode == .favorites
            ? ListSection.byRank(followed, rank: \.lovedRank)
            : ListSection.byMonth(followed, on: \.shelvedAt)
    }
}

#if DEBUG
#Preview {
    @Previewable @State var mode = LibraryMode.all
    @Previewable @State var state: SeriesState?
    NavigationStack {
        SeriesListPage(
            followed: SeriesFixtures.followed, mode: $mode, stateFilter: $state,
            isLoading: false, errorMessage: nil, hasMore: true, loadMoreFailed: false
        ) { _ in }
    }
}

#Preview("No saga yet") {
    NavigationStack {
        SeriesListPage(
            followed: [], mode: .constant(.all), stateFilter: .constant(nil),
            isLoading: false, errorMessage: nil, hasMore: false, loadMoreFailed: false
        ) { _ in }
    }
}
#endif
