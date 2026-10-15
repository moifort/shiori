import SwiftUI

/// Everything a friend's sagas page can ask for.
enum FriendSeriesListAction {
    case openSaga(FriendSaga)
    /// The "+" of a row: the friend's first volume onto the reader's pile,
    /// which makes the saga one of theirs.
    case take(FriendSaga, as: BookFormat)
    case loadMore
    case refresh
}

/// A friend's sagas — or the reader's own, previewed — drawn as the reader's
/// Series tab draws theirs: the saga shelved last first, cut into months, each
/// with its name and author, the heart when they gave one, and every volume
/// on their shelf as a cover carrying its status.
///
/// A row opens the saga on its own page; its "+" is greyed out when the reader
/// already holds a volume of it.
struct FriendSeriesListPage: View {
    let friendName: String
    let sagas: [FriendSaga]
    @Binding var mode: LibraryMode
    @Binding var state: SeriesState?
    /// The rows on screen answer another view or filter, or none yet.
    let isWaiting: Bool
    /// The page could not be read, with nothing of this view to show.
    let loadFailed: String?
    let hasMore: Bool
    let loadMoreFailed: Bool
    /// The rows whose "+" is turning.
    let adding: Set<String>
    /// The reader's own sagas, previewed: every one is theirs already.
    let isPreview: Bool
    let onAction: (FriendSeriesListAction) async -> Void

    private let coverWidth: CGFloat = 44

    var body: some View {
        Group {
            if isWaiting {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let loadFailed {
                EmptyStateView.failure("Séries indisponibles", message: loadFailed) { await onAction(.refresh) }
            } else if sagas.isEmpty {
                Text(
                    state == nil && mode == .all
                        ? "Aucune série n'a été ajoutée à cette bibliothèque."
                        : "Aucune série ne correspond."
                )
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                list
            }
        }
        .navigationTitle("Séries")
        .navigationSubtitle(friendName)
        .toolbar { toolbar }
    }

    private var list: some View {
        List {
            ForEach(sections) { section in
                Section(section.title) {
                    ForEach(section.rows) { saga in
                        HStack(alignment: .top, spacing: 8) {
                            // A tap rather than a button: a button would claim
                            // the drag that scrolls the cover strip.
                            row(saga)
                                .contentShape(.rect)
                                .onTapGesture { Task { await onAction(.openSaga(saga)) } }
                            TakeButton(
                                owned: saga.inLibrary || isPreview || saga.volumes.isEmpty,
                                isAdding: adding.contains(saga.id),
                                format: saga.takenFormat,
                                addLabel: "Ajouter la série à mes séries",
                                ownedLabel: "Série déjà dans votre bibliothèque"
                            ) { format in
                                await onAction(.take(saga, as: format))
                            }
                        }
                        .edgeToEdgeSeparator()
                        .accessibilityIdentifier("friend-series-row")
                    }
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

    /// The same controls as the Series tab: the two views, the state filter
    /// beside them — the saga set aside aside, a friend's state being read
    /// off their volumes alone.
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
                .accessibilityIdentifier("friend-series-mode-\(item.rawValue)")
            }
        }
        ToolbarSpacer(.fixed)
        ToolbarItemGroup {
            Menu {
                Picker("État", selection: $state) {
                    Label("Toutes", systemImage: "tray.full").tag(SeriesState?.none)
                    ForEach([SeriesState.inProgress, .notStarted, .complete]) { state in
                        Label(state.shelfTitle, systemImage: state.symbol)
                            .tag(SeriesState?.some(state))
                    }
                }
            } label: {
                ShelfFilterLabel(
                    symbol: state?.symbol ?? "tray.full",
                    title: state?.shelfTitle ?? String(localized: "Toutes")
                )
            }
            .accessibilityIdentifier("friend-series-filter")
        }
    }

    /// As on the Series tab: the name with its marks on the first line, the
    /// author under it, the covers underneath.
    private func row(_ saga: FriendSaga) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    SagaName(name: saga.name, isAudio: saga.isAudio)
                        .font(.body.weight(.medium))
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    HStack(spacing: 6) {
                        if let language = saga.language, language.isForeign {
                            LanguageTag(language: language)
                        }
                        if let state = saga.state {
                            SeriesStateLabel(state: state)
                        }
                        OpinionMark(rating: saga.rating, isFavorite: saga.favorite, font: .caption)
                    }
                    .font(.caption)
                    .fixedSize()
                }
                if let author = saga.author {
                    Text(author).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            ScrollView(.horizontal) {
                LazyHStack(spacing: 10) {
                    ForEach(saga.volumes) { volume in
                        BookCover(book: volume, width: coverWidth, showsFormatBadge: false)
                            .overlay(alignment: .topTrailing) {
                                ReadingStatusBadge(status: volume.status)
                                    .offset(x: 5, y: -5)
                            }
                    }
                }
                .padding(.top, 5)
            }
            .scrollIndicators(.hidden)
            .accessibilityHidden(true)
        }
        .padding(.vertical, 2)
    }

    /// Cut into months, as the Series tab is — or, under the favourites, into
    /// the hearts and then each count of stars, as the server ranked them.
    private var sections: [ListSection<FriendSaga>] {
        mode == .favorites
            ? ListSection.byRank(sagas, rank: \.lovedRank)
            : ListSection.byMonth(sagas, on: \.shelvedAt)
    }
}

extension FriendSaga: Hashable {
    static func == (lhs: FriendSaga, rhs: FriendSaga) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

#Preview("Nothing matches") {
    NavigationStack {
        FriendSeriesListPage(
            friendName: "Camille", sagas: [], mode: .constant(.all), state: .constant(.complete),
            isWaiting: false, loadFailed: nil, hasMore: false, loadMoreFailed: false,
            adding: [], isPreview: false
        ) { _ in }
    }
}
