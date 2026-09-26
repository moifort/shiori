import SwiftUI

/// A friend's sagas — or the reader's own, previewed — drawn as the reader's
/// Series tab draws theirs: the saga shelved last first, cut into months, each
/// with its name and author, the heart when they gave one, and every volume
/// on their shelf as a cover carrying its status. The next page is asked for
/// as the list runs out.
///
/// A row opens the saga on its own page; its "+" puts the friend's first
/// volume on the reader's pile, which makes it one of their sagas, greyed out
/// when they already hold a volume of it.
struct FriendSeriesListView: View {
    let friendId: String
    let friendName: String
    /// The reader's own sagas, previewed: every one is theirs already.
    var isPreview = false

    @State private var sagas: [FriendSaga] = []
    @State private var mode: LibraryMode = .all
    @State private var state: SeriesState?
    @State private var hasMore = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var loadMoreFailed = false
    @State private var openSaga: FriendSaga?
    @State private var adding: Set<String> = []
    @State private var addFailed: String?

    private let coverWidth: CGFloat = 44

    var body: some View {
        Group {
            if isLoading && sagas.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage, sagas.isEmpty {
                EmptyStateView.failure("Séries indisponibles", message: errorMessage) { await load() }
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
        .task(id: "\(mode.rawValue)-\(state?.rawValue ?? "all")") { await load() }
        // A sheet, as a saga opens from the reader's own Series tab.
        .sheet(item: $openSaga) { saga in
            NavigationStack {
                SeriesView(seriesId: saga.seriesId, language: saga.language, isSheet: true)
            }
        }
        .alert(
            "Ajout impossible",
            isPresented: .init(get: { addFailed != nil }, set: { if !$0 { addFailed = nil } })
        ) {
            Button("OK", role: .cancel) { addFailed = nil }
        } message: {
            Text(addFailed ?? "")
        }
    }

    private var list: some View {
        List {
            ForEach(MonthSection.cut(sagas, on: \.shelvedAt)) { section in
                Section(section.title) {
                    ForEach(section.rows) { saga in
                        HStack(alignment: .top, spacing: 8) {
                            // A tap rather than a button: a button would claim
                            // the drag that scrolls the cover strip.
                            row(saga)
                                .contentShape(.rect)
                                .onTapGesture { openSaga = saga }
                            TakeButton(
                                owned: saga.inLibrary || isPreview || saga.volumes.isEmpty,
                                isAdding: adding.contains(saga.id),
                                addLabel: "Ajouter la série à mes séries",
                                ownedLabel: "Série déjà dans votre bibliothèque"
                            ) {
                                await add(saga)
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
                    onLoadMore: loadMore
                )
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await load() }
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
                Image(systemName: "line.3.horizontal.decrease")
                    .symbolVariant(state != nil ? .fill : .none)
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
                    Text(saga.name).font(.body.weight(.medium)).lineLimit(2)
                    Spacer(minLength: 0)
                    HStack(spacing: 6) {
                        if let language = saga.language, language.isForeign {
                            LanguageTag(language: language)
                        }
                        if let state = saga.state {
                            SeriesStateLabel(state: state)
                        }
                        if saga.favorite {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.red)
                                .accessibilityLabel(Text("Favori"))
                        }
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

    private func load() async {
        isLoading = true
        errorMessage = nil
        loadMoreFailed = false
        do {
            let page = try await FriendsAPI.sagaPage(
                friendId: friendId, state: state, favorite: mode == .favorites, after: nil
            )
            sagas = page.sagas
            hasMore = page.hasMore
        } catch {
            errorMessage = reportError(error)
        }
        isLoading = false
    }

    private func loadMore() async {
        loadMoreFailed = false
        do {
            let page = try await FriendsAPI.sagaPage(
                friendId: friendId, state: state, favorite: mode == .favorites, after: sagas.last?.id
            )
            sagas.append(contentsOf: page.sagas.filter { new in !sagas.contains { $0.id == new.id } })
            hasMore = page.hasMore
        } catch {
            _ = reportError(error)
            loadMoreFailed = true
        }
    }

    private func add(_ saga: FriendSaga) async {
        guard let first = saga.volumes.first else { return }
        adding.insert(saga.id)
        defer { adding.remove(saga.id) }
        do {
            try await FriendsAPI.addBook(friendId: friendId, bookId: first.id, status: .toRead)
            if let index = sagas.firstIndex(where: { $0.id == saga.id }) {
                sagas[index].inLibrary = true
            }
        } catch {
            addFailed = reportError(error)
        }
    }
}

extension FriendSaga: Hashable {
    static func == (lhs: FriendSaga, rhs: FriendSaga) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
