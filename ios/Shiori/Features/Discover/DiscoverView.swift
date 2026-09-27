import SwiftUI

/// The Découvrir tab: every saga the reader follows — all but the ones they
/// set aside — with the next volume announced they do not hold, the soonest
/// first. The volumes already out are not listed: the saga screen shows them
/// under "Tomes", with the button that adds them.
///
/// Laid out as the Library tab is, so nothing here has to be learnt twice: the
/// capsule above the tab bar switches between "Livres" — each volume announced
/// drawn as the Books tab draws a book, the soonest out first, a tap opening
/// its page described on the spot — and "Séries" — the Series tab's rows, every
/// cover of their strip; a tap opens the saga screen as a sheet. Read through one format at a time — the saga read or the
/// saga heard — picked in the toolbar and kept between visits.
///
/// Above what is announced, "Nouvelles parutions": the volumes out in the last
/// week the reader can have now, read off the same weekly look.
///
/// The server looks the sagas up on the web once a week. The tab opens on the
/// rows it last showed, brought up to date silently underneath; sagas nobody
/// ever looked up — every saga, on the very first look — are looked up at once,
/// behind a loader or a row above the others.
struct DiscoverView: View {
    @State private var viewModel = DiscoverViewModel()
    @State private var openSeries: SagaDiscovery?
    /// The volume whose page is open, announced or just out.
    @State private var openVolume: DiscoveryVolume?
    @Environment(\.openURL) private var openURL
    @AppStorage("discover.format") private var format: ReleaseFormat = .book
    @AppStorage("discover-shelf") private var shelf: LibraryShelf = .series
    /// The format was picked this session — by a tap, or once for the reader —
    /// and is kept even when it holds no saga.
    @State private var formatSettled = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Découvrir")
                .toolbar { toolbar }
                .libraryShelfPicker($shelf, shelves: [.books, .series])
                // A sheet, as a book opens from the library.
                .sheet(item: $openSeries) { row in
                    NavigationStack {
                        SeriesView(
                            seriesId: row.series.seriesId,
                            language: row.series.language,
                            isSheet: true
                        )
                    }
                }
                .sheet(item: $openVolume) { opened in
                    NavigationStack {
                        AnnouncedVolumeView(saga: opened.saga, volume: opened.volume)
                    }
                }
        }
        .task(id: format) {
            await viewModel.loadOnAppear(format)
            openOnAFollowedFormat()
        }
        .onReceive(NotificationCenter.default.publisher(for: .shioriDataDidChange)) { _ in
            Task { await viewModel.reload() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLookingUp, viewModel.rows(format)?.isEmpty ?? true {
            // The first look: the sagas are being looked up on the web, and
            // there is nothing to show until they are.
            ProgressView("Recherche des prochaines sorties…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("discover-looking-up")
        } else if let rows = viewModel.rows(format) {
            list(rows)
        } else if let errorMessage = viewModel.errorMessage, !viewModel.isLoading {
            EmptyStateView.failure("Découvrir indisponible", message: errorMessage) {
                await viewModel.load(format)
            }
        } else {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func list(_ rows: [SagaDiscovery]) -> some View {
        List {
            // The snapshot on screen is brought up to date silently. Only a
            // refresh that failed says so, since the rows are then last time's.
            if viewModel.refreshFailed {
                RefreshRow(
                    failed: viewModel.refreshFailed,
                    loadingLabel: "Mise à jour de Découvrir",
                    onRetry: { await viewModel.refresh(format) }
                )
            }
            if viewModel.isLookingUp {
                // Sagas followed since are being looked up: the rows already
                // there stay, the new ones slide in when they are found.
                Section {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Recherche des prochaines sorties…")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            let upcoming = shelf == .books
                ? viewModel.upcoming(format) ?? []
                : rows.filter { $0.releases.next != nil }
            let recentVolumes = viewModel.recentVolumes(format) ?? []
            let recentSagas = viewModel.recentSagas(format) ?? []
            if upcoming.isEmpty && recentSagas.isEmpty && !viewModel.isLookingUp {
                Section {
                    EmptyStateView(
                        systemImage: format == .audiobook ? "headphones" : "sparkles",
                        title: "Rien de neuf pour l'instant",
                        message: format == .audiobook
                            ? "Les nouveautés et les prochains tomes annoncés de vos séries audio apparaîtront ici."
                            : "Les nouveautés et les prochains tomes annoncés de vos séries apparaîtront ici."
                    )
                }
                .listRowBackground(Color.clear)
            }
            if !recentSagas.isEmpty {
                Section {
                    if shelf == .books {
                        ForEach(recentVolumes) { volumeRow($0) }
                    } else {
                        ForEach(recentSagas) { row($0) }
                    }
                } header: {
                    Text("Nouvelles parutions")
                }
                .accessibilityIdentifier("discover-recent")
            }
            if !upcoming.isEmpty {
                Section {
                    ForEach(upcoming) { saga in
                        if shelf == .books {
                            if let next = saga.releases.next {
                                volumeRow(DiscoveryVolume(saga: saga, volume: next))
                            }
                        } else {
                            row(saga)
                        }
                    }
                } header: {
                    Text("Prochaines sorties")
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await viewModel.load(format) }
    }

    /// A volume announced or just out, drawn as the Books tab draws a book: its
    /// saga as a tag, the headphones on the cover of a recording, and on the
    /// trailing edge the day it comes or came out. No genre: the saga already
    /// says what it is.
    ///
    /// A tap opens the volume's page, described on the spot for a scan; a long
    /// press offers its saga, and a recording's page on Audible.
    private func volumeRow(_ opened: DiscoveryVolume) -> some View {
        let saga = opened.saga
        let volume = opened.volume
        let series = saga.series
        let membership = SeriesMembership(
            id: series.seriesId,
            name: series.name,
            volume: volume.number,
            kind: .main
        )
        return BookRow(
            title: volume.title,
            authorLine: series.author ?? "",
            cover: Book(
                id: "release-\(series.id)-\(volume.number)",
                title: volume.title,
                authors: series.author.map { [$0] } ?? [],
                format: series.isAudio ? .audiobook : .book,
                genre: series.genre,
                language: series.language,
                series: membership,
                coverURL: volume.coverURL,
                status: .toRead
            ),
            status: .toRead,
            rating: nil,
            series: membership,
            language: series.language,
            releaseDate: volume.date
        )
        .contentShape(Rectangle())
        .onTapGesture { openVolume = opened }
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { openVolume = opened }
        .contextMenu {
            if let audibleURL = volume.audibleURL {
                Button("Ouvrir dans Audible", systemImage: "headphones") { openURL(audibleURL) }
            }
            Button("Ouvrir la série", systemImage: "books.vertical") { openSeries = saga }
        }
        .accessibilityIdentifier("discover-volume-row")
    }

    /// A saga's row: the Series tab's own, every cover of its strip, and
    /// underneath the next volume and when it comes out.
    private func row(_ row: SagaDiscovery) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SeriesRow(entry: row.series)
                .contentShape(Rectangle())
                // A tap rather than a button: a button would claim the drag
                // that scrolls the cover strip.
                .onTapGesture { openSeries = row }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { openSeries = row }
            SagaReleasesSummary(releases: row.releases, missing: row.missing)
        }
        .contextMenu {
            Button("Ouvrir la série", systemImage: "books.vertical") { openSeries = row }
        }
        .accessibilityIdentifier("discover-series-row")
    }

    /// A reader who follows no saga in the format on screen — every saga of
    /// theirs heard, say — sees the other one instead, once a session: a
    /// format they tapped stays, and two empty formats do not bounce.
    private func openOnAFollowedFormat() {
        guard !formatSettled, viewModel.followed(format) == 0 else { return }
        formatSettled = true
        format = ReleaseFormat.allCases.first { $0 != format } ?? format
    }

    /// The two formats where the Library and Series tabs keep their views: icons
    /// on the right, the one picked in the tint.
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            DiscoverAlertsButton()
        }
        ToolbarItemGroup {
            ForEach(ReleaseFormat.allCases) { item in
                Button {
                    formatSettled = true
                    format = item
                } label: {
                    Label(item.filterLabel, systemImage: item.symbol)
                }
                .labelStyle(.iconOnly)
                .tint(format == item ? .accentColor : .primary)
                .accessibilityIdentifier("discover-format-\(item.rawValue)")
            }
        }
    }
}

/// What a saga has for the reader, in a line under its covers: the next volume
/// announced — its date already hangs under its cover — and the volumes out
/// they have not added yet.
struct SagaReleasesSummary: View {
    let releases: SagaReleases
    let missing: [Int]

    var body: some View {
        let parts = [comingPart, availablePart].compactMap { $0 }
        if !parts.isEmpty {
            Text(verbatim: parts.joined(separator: " · "))
                .foregroundStyle(.orange)
                .font(.footnote.weight(.medium))
                .lineLimit(2)
        }
    }

    private var comingPart: String? {
        releases.next.map { String(localized: "À venir : Tome \($0.number)") }
    }

    private var availablePart: String? {
        guard !missing.isEmpty else { return nil }
        let numbers = missing.map(String.init).joined(separator: ", ")
        return String(localized: "Disponible : Tome \(numbers)")
    }
}

#Preview {
    DiscoverView()
}
