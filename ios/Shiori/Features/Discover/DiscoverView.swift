import SwiftUI

/// The shelves of the Découvrir tab, which the chips narrow to one theme.
enum DiscoverFilter: String, CaseIterable, Identifiable {
    case forYou, upcoming, awards, offTrail, friends
    var id: String { rawValue }

    var label: String {
        switch self {
        case .forYou: String(localized: "Pour vous")
        case .upcoming: String(localized: "À paraître")
        case .awards: String(localized: "Primés")
        case .offTrail: String(localized: "Hors piste")
        case .friends: String(localized: "Amis")
        }
    }
}

/// The Découvrir tab: what to read next, each suggestion with its reason — the
/// friends' hearts, the next volumes of the reader's sagas and when they come
/// out, prize winners and the books readers worldwide love in their genres, and
/// genres they never tried reached through one they love.
///
/// The shelves are prepared by the server once a week. Until the first time,
/// the tab offers to prepare them now; after that, once a day at most.
struct DiscoverView: View {
    @State private var feed: DiscoverFeed?
    @State private var isLoading = true
    @State private var isPreparing = false
    @State private var errorMessage: String?
    @State private var filter: DiscoverFilter = .forYou
    @State private var openSuggestion: Suggestion?
    @State private var openFavorite: FriendFavorite?
    @State private var alerts: Set<AlertKind> = []

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Découvrir")
                .toolbar { toolbar }
                .navigationDestination(item: $openFavorite) { favorite in
                    FriendBookView(
                        friendId: favorite.friendId,
                        bookId: favorite.bookId,
                        friendName: favorite.friendNames.first ?? String(localized: "votre ami"),
                        onAdded: { feed?.remove(key: favorite.key) }
                    )
                }
                .sheet(item: $openSuggestion) { suggestion in
                    SuggestionView(
                        suggestion: suggestion,
                        onDone: { key in feed?.remove(key: key) }
                    )
                }
        }
        .task { await load() }
        // A book added elsewhere may be one of the suggestions: it leaves the
        // tab on the next look.
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
        } else if let feed {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    chips
                    if feed.preparedAt == nil { prepareCard }
                    sections(feed)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .refreshable { await load() }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if let feed, feed.preparedAt != nil, feed.canRefresh {
            ToolbarItem(placement: .primaryAction) {
                if isPreparing {
                    ProgressView()
                } else {
                    Button {
                        Task { await prepare() }
                    } label: {
                        Label("Nouvelles suggestions", systemImage: "arrow.clockwise")
                    }
                    .accessibilityIdentifier("discover-refresh")
                }
            }
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DiscoverFilter.allCases) { chip in
                    Button {
                        withAnimation(.snappy) { filter = chip }
                    } label: {
                        Text(chip.label)
                            .font(.subheadline.weight(filter == chip ? .semibold : .regular))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                filter == chip ? AnyShapeStyle(.tint.opacity(0.18)) : AnyShapeStyle(.background),
                                in: .capsule
                            )
                            .foregroundStyle(filter == chip ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("discover-chip-\(chip.rawValue)")
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, -16)
    }

    private var prepareCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Vos suggestions", systemImage: "sparkles").font(.headline)
            Text("Shiori parcourt ce que vous avez aimé, les séries que vous suivez et ce que les lecteurs du monde entier plébiscitent pour vous proposer vos prochaines lectures. Cela prend une minute.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                Task { await prepare() }
            } label: {
                HStack {
                    if isPreparing { ProgressView().tint(.white) }
                    Text(isPreparing ? "Préparation en cours…" : "Préparer mes suggestions")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isPreparing)
            .accessibilityIdentifier("discover-prepare")
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
    }

    @ViewBuilder
    private func sections(_ feed: DiscoverFeed) -> some View {
        let shows = { (section: DiscoverFilter) in filter == .forYou || filter == section }

        if filter == .forYou || filter == .offTrail, let hero = feed.offTrail.first {
            heroCard(hero)
        }
        if shows(.upcoming), !feed.releases.isEmpty {
            releasesCard(feed.releases)
        }
        if shows(.upcoming), !feed.audible.isEmpty {
            shelf("Nouveau sur Audible", feed.audible) { $0.reason }
        }
        if filter == .forYou {
            ForEach(feed.becauseYouLoved) { loved in
                shelf("Parce que vous avez aimé \(loved.anchor)", loved.items) { $0.book.authorLine }
            }
        }
        if shows(.awards), !feed.awards.isEmpty {
            shelf("Primés dans vos genres", feed.awards) { $0.award ?? $0.book.authorLine }
        }
        if shows(.awards), !feed.acclaimed.isEmpty {
            shelf("Plébiscités par les lecteurs", feed.acclaimed) { suggestion in
                suggestion.publicRating.map { String(format: "%.1f ★", $0) } ?? suggestion.book.authorLine
            }
        }
        if shows(.offTrail), feed.offTrail.count > 1 {
            shelf("Hors des sentiers battus", Array(feed.offTrail.dropFirst())) { $0.book.genre?.label ?? $0.book.authorLine }
        }
        if shows(.friends) {
            friendsShelf(feed.friendsFavorites)
        }
        if feed.preparedAt != nil, feed.isEmpty {
            EmptyStateView(
                systemImage: "sparkles",
                title: "Rien à proposer pour l'instant",
                message: "Mettez un cœur ou cinq étoiles à vos livres préférés : c'est d'eux que partent les suggestions."
            )
        }
    }

    // MARK: - Cards

    private func heroCard(_ suggestion: Suggestion) -> some View {
        Button {
            openSuggestion = suggestion
        } label: {
            HStack(alignment: .top, spacing: 14) {
                BookCover(book: suggestion.book, width: 76)
                VStack(alignment: .leading, spacing: 4) {
                    Label("Hors piste de la semaine", systemImage: "safari")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.purple)
                    Text(suggestion.book.title).font(.headline)
                    Text(suggestion.book.authorLine).font(.subheadline).foregroundStyle(.secondary)
                    Text(suggestion.reason)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(.purple.opacity(0.1), in: .rect(cornerRadius: 20))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("discover-hero")
    }

    private func releasesCard(_ releases: [Release]) -> some View {
        WidgetCard(title: "Bientôt dans vos séries") {
            VStack(spacing: 0) {
                ForEach(releases.prefix(8)) { release in
                    HStack(spacing: 12) {
                        ReleaseDateBadge(date: release.date)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(release.suggestion.book.title).font(.subheadline.weight(.medium)).lineLimit(1)
                                if release.suggestion.book.format == .audiobook {
                                    Image(systemName: "headphones").font(.caption).foregroundStyle(.orange)
                                }
                            }
                            Text(release.suggestion.reason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        bell(for: release.kind)
                    }
                    .padding(.vertical, 8)
                    .contentShape(.rect)
                    .onTapGesture { openSuggestion = release.suggestion }
                    if release.id != releases.prefix(8).last?.id { Divider() }
                }
            }
        }
    }

    /// The alert of a release's kind: tapping the bell switches it on — asking
    /// for permission the first time — or off.
    private func bell(for kind: AlertKind) -> some View {
        let on = alerts.contains(kind)
        return Button {
            Task { await toggleAlert(kind, !on) }
        } label: {
            Image(systemName: on ? "bell.fill" : "bell")
                .foregroundStyle(on ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(on ? "Ne plus me prévenir" : "Me prévenir à la sortie"))
        .accessibilityIdentifier("discover-bell")
    }

    private func shelf(
        _ title: LocalizedStringKey,
        _ items: [Suggestion],
        caption: @escaping (Suggestion) -> String
    ) -> some View {
        WidgetCard(title: title) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(items) { suggestion in
                        Button { openSuggestion = suggestion } label: {
                            CoverTile(book: suggestion.book, caption: caption(suggestion))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.horizontal, -16)
        }
    }

    @ViewBuilder
    private func friendsShelf(_ favorites: [FriendFavorite]) -> some View {
        WidgetCard(title: "Les coups de cœur de vos amis") {
            if favorites.isEmpty {
                WidgetEmptyMessage(
                    text: "Les livres que vos amis adorent et que vous n'avez pas encore apparaîtront ici.",
                    placeholder: .covers
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(favorites) { favorite in
                            Button { openFavorite = favorite } label: {
                                CoverTile(
                                    book: favorite.book,
                                    caption: favorite.friendNames.formatted(.list(type: .and))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.horizontal, -16)
            }
        }
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
        if let settings = try? await NotificationsAPI.settings() { alerts = settings.enabled }
        isLoading = false
    }

    private func prepare() async {
        isPreparing = true
        defer { isPreparing = false }
        do {
            feed = try await DiscoverAPI.refresh()
        } catch {
            errorMessage = reportError(error)
        }
    }

    private func toggleAlert(_ kind: AlertKind, _ enabled: Bool) async {
        if enabled { _ = await PushRegistrar.shared.requestPermission() }
        if let settings = try? await NotificationsAPI.setAlert(kind, enabled: enabled) {
            alerts = settings.enabled
        }
    }
}

/// A release date as a small calendar leaf: the day over the month, or the
/// month over the year, or the year alone — as precisely as it was announced.
struct ReleaseDateBadge: View {
    let date: String

    var body: some View {
        let parts = date.split(separator: "-").compactMap { Int($0) }
        VStack(spacing: 0) {
            Text(verbatim: top(parts)).font(.subheadline.weight(.semibold))
            Text(verbatim: bottom(parts)).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(width: 44)
        .padding(.vertical, 4)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
    }

    private func month(_ number: Int) -> String {
        let symbols = Calendar.current.shortMonthSymbols
        return (1...12).contains(number) ? symbols[number - 1] : ""
    }

    private func top(_ parts: [Int]) -> String {
        switch parts.count {
        case 3: "\(parts[2])"
        case 2: month(parts[1])
        default: parts.first.map(String.init) ?? ""
        }
    }

    private func bottom(_ parts: [Int]) -> String {
        switch parts.count {
        case 3: month(parts[1])
        case 2: String(parts[0])
        default: ""
        }
    }
}

#Preview {
    DiscoverView()
}
