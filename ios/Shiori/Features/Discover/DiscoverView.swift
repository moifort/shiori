import SwiftUI

/// The Découvrir tab: every saga the reader follows — all but the ones they
/// set aside — with the volumes out they do not hold, and the next one
/// announced.
///
/// Laid out as the Library tab is, so nothing here has to be learnt twice: the
/// capsule above the tab bar, for now "Séries" alone; the Series tab's rows,
/// their strip narrowed to the last volume held, the volumes to get ringed in
/// the tint, and the next one with its date; a tap opens the saga screen as a
/// sheet, where each volume can be added or bought. Read through one format at
/// a time — the saga read or the saga heard — picked in the toolbar and kept
/// between visits.
///
/// The server looks the sagas up on the web once a week. The tab opens on the
/// rows it last showed, brought up to date silently underneath.
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
        if let rows = viewModel.rows(format) {
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
        let available = rows.filter { !$0.releases.available.isEmpty }
        let announced = rows.filter { $0.releases.available.isEmpty }
        return List {
            // The snapshot on screen is brought up to date silently. Only a
            // refresh that failed says so, since the rows are then last time's.
            if viewModel.refreshFailed {
                RefreshRow(
                    failed: viewModel.refreshFailed,
                    loadingLabel: "Mise à jour de Découvrir",
                    onRetry: { await viewModel.refresh(format) }
                )
            }
            if rows.isEmpty {
                Section {
                    EmptyStateView(
                        systemImage: format == .audiobook ? "headphones" : "sparkles",
                        title: "Rien de neuf pour l'instant",
                        message: format == .audiobook
                            ? "Les tomes de vos séries audio que vous n'avez pas encore, et les prochains annoncés, apparaîtront ici."
                            : "Les tomes de vos séries que vous n'avez pas encore, et les prochains annoncés, apparaîtront ici."
                    )
                }
                .listRowBackground(Color.clear)
            }
            if !available.isEmpty {
                Section("Disponibles") {
                    ForEach(available) { row($0) }
                }
            }
            if !announced.isEmpty {
                Section {
                    ForEach(announced) { row($0) }
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
    /// here, and underneath what it has for the reader in a line, with the
    /// store the first volume to get is found in.
    private func row(_ row: SagaDiscovery) -> some View {
        var entry = row.series
        entry.strip = row.strip
        return VStack(alignment: .leading, spacing: 8) {
            SeriesRow(entry: entry, offersMissing: true)
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
            ForEach(row.releases.available) { volume in
                Link(destination: volume.storeURL) {
                    Label(
                        String(localized: "Tome \(volume.number) sur \(volume.store.actionLabel)"),
                        systemImage: volume.store == .audible ? "headphones" : "cart"
                    )
                }
            }
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

/// What a saga has for the reader, in a line under its covers: how many
/// volumes are out, in the tint, then the next one and when — and a button to
/// the store the first volume out is found in.
struct SagaReleasesSummary: View {
    let releases: SagaReleases

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Group {
                if !releases.available.isEmpty, let next = releases.next {
                    Text(availableCount).foregroundStyle(Color.accentColor)
                        + Text(verbatim: " · ").foregroundStyle(.secondary)
                        + Text(nextLine(next)).foregroundStyle(.secondary)
                } else if !releases.available.isEmpty {
                    Text(availableCount).foregroundStyle(Color.accentColor)
                } else if let next = releases.next {
                    Text(nextLine(next)).foregroundStyle(.orange)
                }
            }
            .font(.footnote.weight(.medium))
            .lineLimit(2)
            Spacer(minLength: 0)
            if let first = releases.available.first {
                StoreLink(volume: first)
            }
        }
    }

    private var availableCount: AttributedString {
        AttributedString(localized: "^[\(releases.available.count) tome disponible](inflect: true)")
    }

    private func nextLine(_ next: DiscoveredVolume) -> String {
        if let date = next.date {
            return String(localized: "Tome \(next.number) \(ReleaseDateText.phrase(date))")
        }
        return String(localized: "Tome \(next.number) annoncé")
    }
}

/// The button to the store a volume is found in: Amazon for a printed saga,
/// Audible for a saga heard.
struct StoreLink: View {
    let volume: DiscoveredVolume

    var body: some View {
        Link(destination: volume.storeURL) {
            Label(volume.store.actionLabel, systemImage: "arrow.up.right")
                .labelStyle(.titleTrailingIcon)
                .font(.caption.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
        .accessibilityIdentifier("discover-store-link")
    }
}

/// A label with its title first and its icon after, as a link out reads.
private struct TitleTrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.title
            configuration.icon.imageScale(.small)
        }
    }
}

extension LabelStyle where Self == TitleTrailingIconLabelStyle {
    fileprivate static var titleTrailingIcon: TitleTrailingIconLabelStyle { .init() }
}

#Preview {
    DiscoverView()
}
