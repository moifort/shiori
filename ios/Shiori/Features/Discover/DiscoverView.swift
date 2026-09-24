import SwiftUI

/// The Découvrir tab: what is coming next in the sagas the reader follows —
/// in the language they read each in, and in the app's when that differs —
/// and what may interest them, for now the translations out of what they read
/// in another language.
///
/// Laid out as the Library tab is, so nothing here has to be learnt twice: the
/// same "Livres | Séries" capsule above the tab bar, the Series tab's rows and
/// the library's book rows, and a tap opens the very same screens as sheets,
/// with the same corners — a saga's series screen, a book's page, built on the
/// spot for a book the reader does not hold. Swiping a row left, or its sheet's
/// crossed-out eye, sets it aside for good: its releases are no longer looked
/// for. Read through one format at a time, picked in the toolbar and kept
/// between visits.
///
/// The server looks again every day. Until the first time, the tab offers to
/// look now; after that, once a day at most.
struct DiscoverView: View {
    @State private var feed: DiscoverFeed?
    @State private var isLoading = true
    @State private var isPreparing = false
    @State private var errorMessage: String?
    @State private var openSeries: OpenedSeries?
    @State private var openBook: OpenedEdition?
    @AppStorage("discover.format") private var format: ReleaseFormat = .book
    @AppStorage("discover-shelf") private var shelf: LibraryShelf = .series

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Découvrir")
                .navigationSubtitle(lastSearch)
                .toolbar { toolbar }
                .libraryShelfPicker($shelf)
                // A sheet, as a book opens from the library: the same corners
                // on a saga as on a book.
                .sheet(item: $openSeries) { opened in
                    NavigationStack {
                        SeriesView(
                            seriesId: opened.seriesId,
                            language: opened.release.language,
                            isSheet: true,
                            onNotInterested: { Task { await dismiss(opened.release) } }
                        )
                    }
                }
                .sheet(item: $openBook) { opened in
                    BookPreviewView(release: opened.release, edition: opened.edition) {
                        Task { await dismiss(opened.release) }
                    }
                }
        }
        .task { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .shioriDataDidChange)) { _ in
            Task { await load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && feed == nil {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage, feed == nil {
            EmptyStateView.failure("Découvrir indisponible", message: errorMessage) { await load() }
        } else if let whole = feed {
            let feed = whole.narrowed(to: format)
            List {
                if feed.preparedAt == nil {
                    Section { prepareCard }
                } else if shown(feed.upcoming).isEmpty && shown(feed.maybe).isEmpty {
                    Section {
                        EmptyStateView(
                            systemImage: format == .audiobook ? "headphones" : "sparkles",
                            title: "Rien à venir pour l'instant",
                            message: format == .audiobook
                                ? "Les prochains livres audio de vos séries apparaîtront ici. Ils ne sont proposés que si vous avez connecté Audible."
                                : "Les prochains tomes de vos séries apparaîtront ici dès qu'ils sont annoncés."
                        )
                    }
                    .listRowBackground(Color.clear)
                }
                if !shown(feed.upcoming).isEmpty {
                    Section {
                        rows(feed.upcoming, upcoming: true)
                    } header: {
                        Text("À venir")
                    } footer: {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Image(systemName: "bell")
                            Text("Vous recevrez une notification le jour de la sortie.")
                        }
                    }
                }
                if !shown(feed.maybe).isEmpty {
                    Section("Vous intéresse peut-être") {
                        rows(feed.maybe, upcoming: false)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable { await load() }
        }
    }

    /// What the shelf on screen draws of a section: only the sagas on "Séries";
    /// every book on "Livres", the volumes of a saga among them.
    private func shown(_ releases: [Release]) -> [Release] {
        shelf == .series ? releases.filter(\.isSeries) : releases
    }

    /// One section of the shelf on screen: a saga per row on "Séries", as the
    /// Series tab draws it, books on their own left to the other shelf; an
    /// edition per row on "Livres", as the library draws a book — only the ones to come under "À venir", only the ones out
    /// under "Vous intéresse peut-être".
    @ViewBuilder
    private func rows(_ releases: [Release], upcoming: Bool) -> some View {
        switch shelf {
        case .series:
            ForEach(releases.filter(\.isSeries)) { release in
                if let entry = entry(of: release) {
                    SeriesRow(entry: entry)
                        .contentShape(Rectangle())
                        // A tap rather than a button: a button would claim the
                        // drag that scrolls the cover strip.
                        .onTapGesture { open(release) }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { open(release) }
                        .modifier(NotInterested { Task { await dismiss(release) } })
                        .accessibilityIdentifier("discover-series-row")
                }
            }
        case .books:
            ForEach(releases) { release in
                ForEach(release.editions.filter { $0.isUpcoming == upcoming }) { edition in
                    bookRow(release, edition)
                }
            }
        }
    }

    private func bookRow(_ release: Release, _ edition: ReleaseEdition) -> some View {
        let book = release.book(edition)
        return Button {
            openBook = OpenedEdition(release: release, edition: edition)
        } label: {
            HStack(alignment: .center, spacing: 8) {
                BookRow(
                    title: book.title,
                    authorLine: book.authorLine,
                    cover: book,
                    status: .toRead,
                    rating: nil,
                    series: book.series,
                    language: release.language
                )
                if edition.isUpcoming, let date = edition.date {
                    ReleaseDateBadge(date: date)
                }
            }
        }
        .tint(.primary)
        .modifier(NotInterested { Task { await dismiss(release) } })
        .accessibilityIdentifier("discover-book-row")
    }

    /// A saga's row: the Series tab's own, its strip drawn from the catalogue
    /// in that language. A saga nobody catalogued draws its strip from what the
    /// web found instead, so the announced volume still shows with its date.
    private func entry(of release: Release) -> FollowedSeries? {
        guard var entry = release.series else { return nil }
        if entry.strip.isEmpty && entry.volumes.isEmpty {
            entry.strip = release.editions.compactMap { edition in
                edition.volume.map { number in
                    .missing(
                        key: "\(release.key)-\(number)",
                        number: number,
                        title: edition.title,
                        forthcoming: edition.isUpcoming,
                        date: edition.date,
                        coverURL: edition.coverURL
                    )
                }
            }
        }
        return entry
    }

    private func open(_ release: Release) {
        guard let seriesId = release.seriesId else { return }
        openSeries = OpenedSeries(seriesId: seriesId, release: release)
    }

    /// The two formats where the Library and Series tabs keep their views: icons
    /// on the right, the one picked in the tint.
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup {
            ForEach(ReleaseFormat.allCases) { item in
                Button {
                    format = item
                } label: {
                    Label(item.filterLabel, systemImage: item.symbol)
                }
                .labelStyle(.iconOnly)
                .tint(format == item ? .accentColor : .primary)
                .accessibilityIdentifier("discover-format-\(item.rawValue)")
            }
        }
        if let feed, feed.preparedAt != nil, feed.canRefresh {
            ToolbarSpacer(.fixed)
            ToolbarItem {
                if isPreparing {
                    ProgressView()
                } else {
                    Button {
                        Task { await prepare() }
                    } label: {
                        Label("Chercher à nouveau", systemImage: "arrow.clockwise")
                    }
                    .accessibilityIdentifier("discover-refresh")
                }
            }
        }
    }

    /// When the web was last searched for what is new, under the title: the
    /// tab is only as fresh as that, and the reader should not wonder why an
    /// announcement from this morning is not there yet.
    private var lastSearch: String {
        guard let preparedAt = feed?.preparedAt else { return "" }
        return String(localized: "Mis à jour \(preparedAt.formatted(.relative(presentation: .named)))")
    }

    private var prepareCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Les prochains tomes de vos séries", systemImage: "sparkles").font(.headline)
            Text("Shiori cherche, pour chaque série que vous lisez, le prochain tome annoncé et sa date — dans la langue où vous la lisez, et en français quand vous la lisez dans une autre langue —, en livre, et en livre audio si vous avez connecté Audible. Cela prend une minute.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                Task { await prepare() }
            } label: {
                HStack {
                    if isPreparing { ProgressView().tint(.white) }
                    Text(isPreparing ? "Recherche en cours…" : "Chercher les sorties")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isPreparing)
            .accessibilityIdentifier("discover-prepare")
        }
        .padding(.vertical, 6)
    }

    // MARK: - Loading

    private func load() async {
        isLoading = true
        do {
            feed = try await DiscoverAPI.feed()
            errorMessage = nil
        } catch {
            errorMessage = reportError(error)
        }
        isLoading = false
        await askForAlertsIfWorthIt()
    }

    private func prepare() async {
        isPreparing = true
        defer { isPreparing = false }
        do {
            feed = try await DiscoverAPI.refresh()
            errorMessage = nil
        } catch {
            errorMessage = reportError(error)
        }
        await askForAlertsIfWorthIt()
    }

    /// The alert is on by default, but the system asks once: the first time
    /// the tab has a release to announce, which is when saying yes means
    /// something. Asked once, the system never shows it again.
    private func askForAlertsIfWorthIt() async {
        guard let feed, !feed.upcoming.isEmpty else { return }
        _ = await PushRegistrar.shared.requestPermission()
    }

    private func dismiss(_ release: Release) async {
        withAnimation { feed?.remove(key: release.key) }
        do {
            try await DiscoverAPI.dismiss(key: release.key)
        } catch {
            errorMessage = reportError(error)
            await load()
        }
    }
}

/// A book of the tab opened over it, with the release it belongs to.
private struct OpenedEdition: Identifiable {
    let release: Release
    let edition: ReleaseEdition
    var id: String { "\(release.key)-\(edition.id)" }
}

/// A saga of the tab opened over it, with the release it came from.
private struct OpenedSeries: Identifiable {
    let seriesId: String
    let release: Release
    var id: String { release.key }
}

/// "Pas intéressé", by a swipe or a long press, on every row of the tab.
private struct NotInterested: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive, action: action) {
                    Label("Pas intéressé", systemImage: "eye.slash")
                }
            }
            .contextMenu {
                Button(role: .destructive, action: action) {
                    Label("Pas intéressé", systemImage: "eye.slash")
                }
            }
    }
}

#Preview {
    DiscoverView()
}
