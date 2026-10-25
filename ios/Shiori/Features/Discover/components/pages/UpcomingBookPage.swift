import SwiftUI

/// Where a book to come is ordered: the recording on Audible, the printed
/// edition on Amazon.
struct UpcomingStore {
    let url: URL
    let isAudible: Bool

    var logo: String { isAudible ? "audible-logo" : "amazon-logo" }

    /// The link closing the facts, as a book's page words it.
    var factLink: FactLink {
        isAudible
            ? FactLink(id: "audible", title: "Écouter sur Audible", logo: logo, url: url)
            : FactLink(id: "amazon", title: "Voir sur Amazon", logo: logo, url: url)
    }
}

/// What the bell asks before it falls silent, when giving up cannot be
/// undone from the page: an edition awaited stops being watched for good.
struct BellConfirmation {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let action: LocalizedStringKey
}

/// A book to come, opened from "Nouveautés" or Découvrir — a volume
/// announced, an edition awaited — drawn as the reader's own book page is,
/// so nothing new is to be learnt: the hero over the cover's colours, then
/// the summary, the saga, the facts. What a book to come adds is in the hero
/// alone: the day as a calendar leaf on glass in its corner, how long is left
/// tagged after the format, and the saga page's row of actions — the white
/// button that orders it from its store, the "+" that puts it on the pile
/// when the reader can, and the bell that alerts on the day, which swings
/// when tapped. A recording differs only by what the hero already says of
/// one: its "Audio" tag and who reads it. Pure and previewable.
struct UpcomingBookPage: View {
    /// The book as described, or as the look on the web knows it until then.
    let book: Book
    /// `YYYY`, `YYYY-MM` or `YYYY-MM-DD`; nil for one announced with no date.
    let releaseDate: String?
    let isDescribing: Bool
    let store: UpcomingStore?
    /// Whether the bell alerts on the day.
    let isAlerted: Bool
    /// Asked before the bell falls silent; nil silences it at once.
    var bellConfirmation: BellConfirmation? = nil
    /// Said on the detail line: once added, once out.
    var state: BookState? = nil
    /// Nil where the reader has the book already: no "+".
    var isAdded: Bool? = nil
    /// Tiles heading the facts: the title in its own language.
    var leadingTiles: [FactTile] = []
    /// The saga's volumes, held or lacking; empty draws no row.
    var sagaName: String? = nil
    var sagaVolumes: [SeriesStripItem] = []
    /// The volume of the row the page is about, ringed: the reader's copy
    /// an edition is awaited of. Nil for this book itself, which takes the
    /// place of its number in the row.
    var currentVolumeId: String? = nil
    /// False when the page is pushed: Back closes it, not a Close button.
    var showsClose = true
    var onClose: () -> Void = {}
    var onAdd: () async -> Void = {}
    let onToggleBell: () -> Void
    var onOpenSaga: () -> Void = {}
    var onOpenVolume: (Book) -> Void = { _ in }

    /// Bumped on each tap of the bell, which swings as a bell rings.
    @State private var rings = 0
    @State private var confirmsSilence = false

    /// The height of the hero's buttons, the saga page's.
    private static let buttonHeight: CGFloat = 50

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                VStack(alignment: .leading, spacing: 28) {
                    synopsis
                    saga
                    facts
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
        }
        // The bar's buttons float over the page as it scrolls, as on a book's.
        .scrollEdgeEffectHidden(true, for: .top)
        .background(Color(.systemGroupedBackground))
        .generatingInBar(isDescribing ? "L'IA complète la fiche" : nil)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsClose {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel, action: onClose)
                }
            }
            // The hero's "+" again, within reach once it has scrolled away.
            if let isAdded {
                ToolbarItem(placement: .primaryAction) {
                    AsyncToolbarButton(title: "Ajouter à ma pile", systemImage: "plus", action: onAdd)
                        .disabled(isAdded)
                        .accessibilityIdentifier("upcoming-toolbar-add")
                }
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        BookHero(
            book: book,
            state: state,
            showsLength: false,
            releaseDate: releaseDate,
            countdown: releaseDate.flatMap { ReleaseDateText.countdown($0) }
        ) {
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    if let store { storeButton(store) }
                    if let isAdded { addButton(isAdded) }
                    bell
                }
            }
        }
    }

    /// The white button of the saga page's hero, at its content's width:
    /// "Précommander" while the book is to come, "Acheter" once out, with
    /// its store's logo.
    private func storeButton(_ store: UpcomingStore) -> some View {
        Link(destination: store.url) {
            HStack(spacing: 8) {
                Text(isUpcoming ? "Précommander" : "Acheter")
                Image(store.logo)
                    .resizable()
                    .scaledToFit()
                    .frame(width: store.isAudible ? 30 : 44, height: 16)
                    .accessibilityHidden(true)
            }
            .font(.headline)
            .foregroundStyle(.black)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 22)
            .frame(height: Self.buttonHeight)
            .background(.white, in: .capsule)
            .shadow(color: .black.opacity(0.45), radius: 11, y: 8)
        }
        .accessibilityIdentifier("upcoming-store")
    }

    /// On the pile, round on glass beside the store; a tick once there.
    private func addButton(_ isAdded: Bool) -> some View {
        AsyncRoundButton(
            title: isAdded ? "Dans votre pile" : "Ajouter à ma pile",
            systemImage: isAdded ? "checkmark" : "plus",
            side: Self.buttonHeight,
            action: onAdd
        )
        .disabled(isAdded)
        .accessibilityIdentifier("upcoming-add")
    }

    /// Alerts on the day, or falls silent: a tap swings it as a bell rings,
    /// then strikes it through or clears it — asking first where silencing
    /// cannot be undone here.
    private var bell: some View {
        Button {
            if isAlerted, bellConfirmation != nil {
                confirmsSilence = true
            } else {
                ring()
            }
        } label: {
            Image(systemName: isAlerted ? "bell" : "bell.slash")
                .font(.title3.weight(.medium))
                .foregroundStyle(.white)
                .symbolEffect(.wiggle, value: rings)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: Self.buttonHeight, height: Self.buttonHeight)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .sensoryFeedback(.selection, trigger: rings)
        .accessibilityLabel(Text(isAlerted ? "Ne plus être prévenu" : "Être prévenu de la sortie"))
        .accessibilityIdentifier(isAlerted ? "upcoming-silence" : "upcoming-alert")
        // Attached to the bell, as a saga's deletion is: the dialog rises
        // from the control that asked.
        .confirmationDialog(
            bellConfirmation?.title ?? "",
            isPresented: $confirmsSilence,
            titleVisibility: .visible
        ) {
            if let bellConfirmation {
                Button(bellConfirmation.action, role: .destructive) { ring() }
                    .accessibilityIdentifier("upcoming-confirm-silence")
                Button("Annuler", role: .cancel) {}
            }
        } message: {
            if let bellConfirmation { Text(bellConfirmation.message) }
        }
    }

    private func ring() {
        rings += 1
        onToggleBell()
    }

    private var isUpcoming: Bool {
        releaseDate.map { ReleaseDateText.isUpcoming($0) } ?? true
    }

    // MARK: - Blocks

    /// The summary once the model wrote it; nothing while it writes, the bar
    /// saying so.
    @ViewBuilder private var synopsis: some View {
        if !isDescribing, let synopsis = book.synopsis, !synopsis.isEmpty {
            BookSynopsisBlock(synopsis: synopsis)
        }
    }

    @ViewBuilder private var saga: some View {
        if let sagaName, !sagaVolumes.isEmpty {
            SeriesVolumesRow(
                name: sagaName,
                volumes: rowVolumes,
                currentId: currentVolumeId ?? book.id,
                onOpenSeries: onOpenSaga,
                onOpenVolume: onOpenVolume
            )
        }
    }

    /// The row with this book drawn in its own place, its cover bright and
    /// ringed, rather than as the volume it lacks.
    private var rowVolumes: [SeriesStripItem] {
        guard currentVolumeId == nil, let number = book.series?.volume else { return sagaVolumes }
        return sagaVolumes.map { item in
            if case let .missing(_, itemNumber, _, _, _, _) = item, itemNumber == number { .owned(book) } else { item }
        }
    }

    /// What the book is, as a book's page tiles it, the day it is out in
    /// full rather than its year, and its store closing them.
    private var facts: some View {
        VStack(alignment: .leading, spacing: 12) {
            RowHeader(title: "Informations")
            FactGrid(groups: [FactGroup(tiles: leadingTiles + tiles)], links: store.map { [$0.factLink] } ?? [])
        }
    }

    private var tiles: [FactTile] {
        book.readOnlyFactTiles.map { tile in
            guard tile.id == "firstPublishedIn", let releaseDate else { return tile }
            return FactTile(id: tile.id, title: tile.title, value: ReleaseDateText.full(releaseDate))
        }
    }
}

/// A round glass button that waits for its action, a spinner in its place
/// meanwhile, as the bar's own does.
private struct AsyncRoundButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    let side: CGFloat
    let action: () async -> Void

    @State private var isInProgress = false

    var body: some View {
        Button {
            guard !isInProgress else { return }
            isInProgress = true
            Task {
                await action()
                isInProgress = false
            }
        } label: {
            Group {
                if isInProgress {
                    ProgressView()
                } else {
                    Image(systemName: systemImage)
                        .font(.title3.weight(.medium))
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .foregroundStyle(.white)
            .frame(width: side, height: side)
            .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(Text(title))
    }
}

#Preview("Volume announced") {
    NavigationStack {
        UpcomingBookPage(
            book: DiscoveryVolume.preview.book.described(by: .preview),
            releaseDate: Calendar.current.date(byAdding: .day, value: 79, to: .now)!
                .formatted(.iso8601.year().month().day()),
            isDescribing: false,
            store: UpcomingStore(url: URL(string: "https://www.amazon.fr")!, isAudible: false),
            isAlerted: true,
            isAdded: false,
            sagaName: "Dungeon Crawler Carl",
            sagaVolumes: [.missing(key: "dcc-8", number: 8, title: "Le Livre du Carnage", forthcoming: true, date: "2026-11-05")]
        ) {}
    }
}

#Preview("Recording awaited") {
    NavigationStack {
        UpcomingBookPage(
            book: AwaitedEdition.preview.cover.described(by: .preview),
            releaseDate: AwaitedEdition.preview.date,
            isDescribing: true,
            store: UpcomingStore(url: URL(string: "https://www.audible.fr")!, isAudible: true),
            isAlerted: true,
            bellConfirmation: BellConfirmation(
                title: "Ne plus suivre ce livre ?",
                message: "Vous ne serez plus prévenu de sa sortie.",
                action: "Ne plus suivre"
            )
        ) {}
    }
}
