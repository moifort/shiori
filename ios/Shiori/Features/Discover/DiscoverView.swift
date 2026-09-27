import SwiftUI

/// The Découvrir tab: every saga the reader follows — all but the ones they
/// set aside — with the next volume announced they do not hold, the soonest
/// first. The volumes already out are not listed: the saga screen shows them
/// under "Tomes", with the button that adds them.
///
/// Laid out as the Library tab is, so nothing here has to be learnt twice: the
/// capsule above the tab bar, for now "Séries" alone; the Series tab's rows,
/// their strip narrowed to the last volume held and the next one with its
/// date; a tap opens the saga screen as a sheet. Read through one format at a
/// time — the saga read or the saga heard — picked in the toolbar and kept
/// between visits.
///
/// The server looks the sagas up on the web once a week. The tab opens on the
/// rows it last showed, brought up to date silently underneath; sagas nobody
/// ever looked up — every saga, on the very first look — are looked up at once,
/// behind a loader or a row above the others.
struct DiscoverView: View {
    @State private var viewModel = DiscoverViewModel()
    @State private var openSeries: SagaDiscovery?
    @AppStorage("discover.format") private var format: ReleaseFormat = .book
    @AppStorage("discover-shelf") private var shelf: LibraryShelf = .series

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Découvrir")
                .toolbar { toolbar }
                .libraryShelfPicker($shelf, shelves: [.series])
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
        }
        .task(id: format) { await viewModel.loadOnAppear(format) }
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
            if rows.isEmpty && !viewModel.isLookingUp {
                Section {
                    EmptyStateView(
                        systemImage: format == .audiobook ? "headphones" : "sparkles",
                        title: "Rien de neuf pour l'instant",
                        message: format == .audiobook
                            ? "Les prochains tomes annoncés de vos séries audio apparaîtront ici."
                            : "Les prochains tomes annoncés de vos séries apparaîtront ici."
                    )
                }
                .listRowBackground(Color.clear)
            }
            if !rows.isEmpty {
                Section {
                    ForEach(rows) { row($0) }
                } header: {
                    Text("À venir")
                } footer: {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Image(systemName: "bell")
                        Text("Vous recevrez une notification le jour de la sortie.")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await viewModel.load(format) }
    }

    /// A saga's row: the Series tab's own, its strip narrowed to what matters
    /// here, and underneath the next volume and when it comes out.
    private func row(_ row: SagaDiscovery) -> some View {
        var entry = row.series
        entry.strip = row.strip
        return VStack(alignment: .leading, spacing: 8) {
            SeriesRow(entry: entry)
                .contentShape(Rectangle())
                // A tap rather than a button: a button would claim the drag
                // that scrolls the cover strip.
                .onTapGesture { openSeries = row }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { openSeries = row }
            SagaReleasesSummary(releases: row.releases)
        }
        .contextMenu {
            Button("Ouvrir la série", systemImage: "books.vertical") { openSeries = row }
        }
        .accessibilityIdentifier("discover-series-row")
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
    }
}

/// The next volume of a saga and when it comes out, in a line under its covers.
struct SagaReleasesSummary: View {
    let releases: SagaReleases

    var body: some View {
        if let next = releases.next {
            Text(nextLine(next))
                .foregroundStyle(.orange)
                .font(.footnote.weight(.medium))
                .lineLimit(2)
        }
    }

    private func nextLine(_ next: DiscoveredVolume) -> String {
        if let date = next.date {
            return String(localized: "Tome \(next.number) \(ReleaseDateText.phrase(date))")
        }
        return String(localized: "Tome \(next.number) annoncé")
    }
}

#Preview {
    DiscoverView()
}
