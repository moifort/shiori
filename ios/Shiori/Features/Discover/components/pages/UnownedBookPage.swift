import SwiftUI

/// Where a book the reader does not hold is ordered: the recording on
/// Audible, the printed edition on Amazon.
struct UnownedBookStore {
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

/// What the "+" of a book not in the library makes of it: on the pile,
/// read already, or on the wishlist.
enum UnownedBookAddition: CaseIterable, Sendable {
    case pile, read, wishlist
}

/// What the bell asks before it falls silent, when giving up cannot be
/// undone from the page: an edition awaited stops being watched for good.
struct BellConfirmation {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let action: LocalizedStringKey
}

/// A book that is not in the reader's library — a volume announced or out,
/// an edition awaited — opened from "Nouveautés", Découvrir or a saga, and
/// drawn as the reader's own book page is, so nothing new is to be learnt:
/// the hero over the cover's colours, then the summary, the saga, the facts.
/// What it adds is in the hero alone, its first button always white with its
/// label and icon, the others round on glass: the day as a calendar leaf on glass in
/// its corner while it is to come, how long is left tagged after the format,
/// and the saga page's row of actions — the white button that orders it from
/// its store, the "+" once it is out, which opens the suggestion's menu where
/// more than the pile is offered, and the bell that alerts on the day while
/// it is to come, which swings when tapped. A recording differs only
/// by what the hero already says of one: its "Audio" tag and who reads it.
/// Pure and previewable.
struct UnownedBookPage: View {
    /// The book as described, or as the look on the web knows it until then.
    let book: Book
    /// `YYYY`, `YYYY-MM` or `YYYY-MM-DD`; nil for one announced with no date.
    let releaseDate: String?
    let isDescribing: Bool
    let store: UnownedBookStore?
    /// Whether the bell alerts on the day.
    let isAlerted: Bool
    /// Asked before the bell falls silent; nil silences it at once.
    var bellConfirmation: BellConfirmation? = nil
    /// Said on the detail line: once added, once out.
    var state: BookState? = nil
    /// Where the edition stands, as an outlined tag beside the format's:
    /// "Pas annoncé" while nothing is.
    var stateTag: String? = nil
    /// Whether it is out, when its store said so; nil reads it off the date.
    var isOut: Bool? = nil
    /// Nil where the reader has the book already: no "+". None either while
    /// the book is to come: only a book out goes on the pile.
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
    /// What the "+" offers: one, it adds at once; more, it opens a menu.
    var additions: [UnownedBookAddition] = [.pile]
    var onAdd: (UnownedBookAddition) async -> Void = { _ in }
    /// Whether the book is on the wishlist, once it is out: "+ Ajouter" then
    /// offers it and says "Envie" once there. Nil draws the "+" alone (a book
    /// wished for already).
    var isWished: Bool? = nil
    var onToggleWish: () async -> Void = {}
    /// What the "+" made of the book, said in its capsule; a second tap
    /// undoes it.
    var taken: TakenState? = nil
    var onUndo: () async -> Void = {}
    /// Bumped by the caller on each refusal: the hero's buttons shake.
    var refusals = 0
    let onToggleBell: () -> Void
    var onOpenSaga: () -> Void = {}
    var onOpenVolume: (Book) -> Void = { _ in }
    /// The page of a volume of the saga the reader lacks. Nil opens the saga.
    var onOpenLacking: ((DiscoveredVolume) -> Void)? = nil
    /// "Retirer", at the end of the hero's row, asked first: a book wished for
    /// leaves the list, an edition awaited stops being watched. Nil draws no
    /// button; none either beside the bell, which already says it.
    var onNoLongerInterested: (() async -> Void)? = nil
    /// "Couverture" in the "…" of the bar: another cover picked for the book,
    /// for every reader. Nil draws no "…".
    var onChooseCover: (() -> Void)? = nil
    /// The friend the book was wished for or awaited at: their first name,
    /// over their word on it under the facts, as a book's page draws who
    /// recommended it. Nil draws nothing.
    var recommendedBy: String? = nil

    /// Bumped on each tap of the bell, which swings as a bell rings.
    @State private var rings = 0
    @State private var confirmsSilence = false
    /// The choice of the "+" menu being sent, its button turning.
    @State private var adding = false

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
                    recommendation
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
        }
        // The bar's buttons float over the page as it scrolls, as on a book's.
        .scrollEdgeEffectHidden(true, for: .top)
        .background(Color(.systemGroupedBackground))
        .generatingPill(isDescribing)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsClose {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel, action: onClose)
                }
            }
            if let onChooseCover {
                ToolbarItem(placement: .primaryAction) {
                    UnownedBookActionsMenu(onChooseCover: onChooseCover)
                }
            }
        }
    }

    /// Who recommended it, as the page of a book in the library says it: a
    /// friend's bubble under "Commentaires". Nothing is typed here: the
    /// friend's shelf is where the book was seen, and that is their word.
    @ViewBuilder private var recommendation: some View {
        if let recommendedBy {
            VStack(alignment: .leading, spacing: 12) {
                RowHeader(title: "Commentaires")
                MessageBubble(text: String(localized: "Je te le conseille."), sender: recommendedBy)
                    .accessibilityIdentifier("unowned-recommendation-comment")
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        BookHero(
            book: book,
            state: state,
            stateTag: stateTag,
            showsLength: false,
            // The day pinned in the corner while it is to come only: once
            // out, the detail line says when.
            releaseDate: isUpcoming ? releaseDate : nil,
            countdown: isUpcoming ? releaseDate.flatMap { ReleaseDateText.countdown($0) } : nil
        ) {
            HStack(spacing: 10) {
                GlassEffectContainer(spacing: 10) {
                    HStack(spacing: 10) {
                        if let store { storeButton(store) }
                        if let isAdded = offeredAddition, additions.count == 1, isWished == nil { addButton(isAdded) }
                        // Nothing left to alert on once it is out.
                        if isUpcoming { bell }
                    }
                }
                // Outside the glass container: a menu inside one loses the
                // taps that move over a neighbouring button.
                if offeredAddition != nil, let isWished {
                    wishAndAdd(isWished: isWished)
                } else if let isAdded = offeredAddition, additions.count > 1 {
                    addMenu(isAdded)
                }
                if let onNoLongerInterested, !isUpcoming, taken == nil {
                    AsyncRoundButton(
                        title: "Retirer",
                        systemImage: "bookmark.slash",
                        side: Self.buttonHeight,
                        isPrimary: lead == .remove,
                        confirmation: "Retirer de la liste d'envies ?",
                        action: onNoLongerInterested
                    )
                    .accessibilityIdentifier("unowned-remove")
                }
            }
            .refusalShake(trigger: refusals)
        }
    }

    /// "+ Ajouter", as on a prize's page: its menu holds the pile, the books
    /// read and the wish list, and once a choice went through its capsule
    /// says it ("Envie", "À lire", "Lu"); a second tap undoes it. Beside a
    /// store, which keeps the white and the room, it is the round "+".
    private func wishAndAdd(isWished: Bool) -> some View {
        AddMenuButton(
            size: .page,
            isRound: store != nil,
            done: taken ?? (isWished ? .wished : nil),
            isWorking: adding,
            onUndo: {
                if taken == nil, isWished {
                    Task { await onToggleWish() }
                    return
                }
                adding = true
                Task {
                    await onUndo()
                    adding = false
                }
            }
        ) {
            additionButtons(withWish: false)
            Section {
                Button("Ajouter à la liste d'envies", systemImage: "bookmark") { Task { await onToggleWish() } }
                    .accessibilityIdentifier("unowned-add-wishlist")
            }
        }
    }

    /// The white button of the saga page's hero, at its content's width:
    /// "Précommander" while the book is to come, "Commander" once out, with
    /// its store's logo.
    private func storeButton(_ store: UnownedBookStore) -> some View {
        Link(destination: store.url) {
            HStack(spacing: 8) {
                Text(isUpcoming ? "Précommander" : "Commander")
                Image(store.logo)
                    .resizable()
                    .scaledToFit()
                    .frame(width: store.isAudible ? 30 : 44, height: 16)
                    .accessibilityHidden(true)
            }
            .font(.headline)
            .lineLimit(1)
            .fixedSize()
        }
        .buttonStyle(ActionButtonStyle(fill: .white, height: Self.buttonHeight, isRaised: true))
        .accessibilityIdentifier("unowned-store")
    }

    /// The row's first button, white with its label and icon: the store,
    /// else the "+", else the bell, else "Retirer".
    private enum Lead { case store, add, bell, remove }

    private var lead: Lead? {
        if store != nil { return .store }
        if offeredAddition != nil { return .add }
        if isUpcoming { return .bell }
        if onNoLongerInterested != nil { return .remove }
        return nil
    }

    /// On the pile, round on glass beside the store, or first in the row
    /// with no store; a tick once there.
    private func addButton(_ isAdded: Bool) -> some View {
        AsyncRoundButton(
            title: isAdded ? "Ajouté" : "Ajouter",
            systemImage: isAdded ? "checkmark" : "plus",
            side: Self.buttonHeight,
            isPrimary: lead == .add,
            action: { await onAdd(.pile) }
        )
        .disabled(isAdded)
        .accessibilityIdentifier("unowned-add")
    }

    /// The suggestion's "+": on the pile, read already, or on the wishlist,
    /// round on glass beside the store; a tick once added.
    private func addMenu(_ isAdded: Bool) -> some View {
        Menu {
            additionButtons(withWish: true)
        } label: {
            if lead == .add {
                HStack(spacing: 8) {
                    if adding {
                        ProgressView()
                    } else {
                        Image(systemName: isAdded ? "checkmark" : "plus")
                            .contentTransition(.symbolEffect(.replace))
                    }
                    Text(isAdded ? "Ajouté" : "Ajouter")
                }
                .font(.headline)
                .lineLimit(1)
                .fixedSize()
            } else {
                Group {
                    if adding {
                        ProgressView()
                    } else {
                        Image(systemName: isAdded ? "checkmark" : "plus")
                            .font(.title3.weight(.medium))
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
            }
        }
        .menuStyle(.button)
        .buttonStyle(lead == .add
            ? ActionButtonStyle(fill: .white, height: Self.buttonHeight, isRaised: true)
            : ActionButtonStyle(fill: .glass, shape: .circle, height: Self.buttonHeight))
        .disabled(isAdded || adding)
        .accessibilityLabel(Text(isAdded ? "Ajouté" : "Ajouter"))
        .accessibilityIdentifier("unowned-add")
    }

    /// The choices of the "+", in the hero and in the bar: the wishlist only
    /// where no "Envies" holds it.
    @ViewBuilder private func additionButtons(withWish: Bool) -> some View {
        if additions.contains(.pile) {
            Button(book.format == .audiobook ? "À écouter" : "À lire", systemImage: "bookmark.fill") { add(.pile) }
                .accessibilityIdentifier("unowned-add-pile")
        }
        if additions.contains(.read) {
            Button(book.format == .audiobook ? "Déjà écouté" : "Déjà lu", systemImage: "checkmark") { add(.read) }
                .accessibilityIdentifier("unowned-add-read")
        }
        if withWish, additions.contains(.wishlist) {
            Section {
                Button("Ajouter à la liste d'envies", systemImage: "bookmark") { add(.wishlist) }
                    .accessibilityIdentifier("unowned-add-wishlist")
            }
        }
    }

    private func add(_ addition: UnownedBookAddition) {
        adding = true
        Task {
            await onAdd(addition)
            adding = false
        }
    }

    /// Alerts on the day, or falls silent: a tap swings it as a bell rings,
    /// then strikes it through or clears it — asking first where silencing
    /// cannot be undone here. Alone in the row, with no store to buy from, it
    /// is the white button and says what it does: "Suivi", "Suivre".
    private var bell: some View {
        Button {
            if isAlerted, bellConfirmation != nil {
                confirmsSilence = true
            } else {
                ring()
            }
        } label: {
            if bellIsAlone {
                HStack(spacing: 8) {
                    bellSymbol
                    Text(isAlerted ? "Suivi" : "Suivre")
                }
                .font(.headline)
                .lineLimit(1)
                .fixedSize()
            } else {
                bellSymbol
                    .font(.title3.weight(.medium))
            }
        }
        // Alone, the white lead in words; round beside a store, the bell on
        // white while it alerts and slashed on glass once silent.
        .buttonStyle(bellIsAlone
            ? ActionButtonStyle(fill: .white, height: Self.buttonHeight, isRaised: true)
            : ActionButtonStyle(fill: isAlerted ? .white : .glass, shape: .circle, height: Self.buttonHeight))
        .animation(.snappy, value: isAlerted)
        .sensoryFeedback(trigger: isAlerted) { _, alerted in alerted ? .success : .impact(weight: .light) }
        .accessibilityLabel(Text(isAlerted ? "Ne plus être prévenu" : "Être prévenu de la sortie"))
        .accessibilityIdentifier(isAlerted ? "unowned-silence" : "unowned-alert")
        // Attached to the bell, as a saga's deletion is: the dialog rises
        // from the control that asked.
        .confirmationDialog(
            bellConfirmation?.title ?? "",
            isPresented: $confirmsSilence,
            titleVisibility: .visible
        ) {
            if let bellConfirmation {
                Button(bellConfirmation.action, role: .destructive) { ring() }
                    .accessibilityIdentifier("unowned-confirm-silence")
                Button("Annuler", role: .cancel) {}
            }
        } message: {
            if let bellConfirmation { Text(bellConfirmation.message) }
        }
    }

    private var bellSymbol: some View {
        Image(systemName: isAlerted ? "bell" : "bell.slash")
            .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp)))
            .iconGesture(.swing, trigger: rings)
    }

    /// The bell is the row's only button: nothing to buy yet.
    private var bellIsAlone: Bool { lead == .bell }

    private func ring() {
        rings += 1
        onToggleBell()
    }

    /// The "+", once the book is out: whether it is on the pile already.
    private var offeredAddition: Bool? { isUpcoming ? nil : isAdded }

    /// To come, unless its store says it is out: an edition out may carry no
    /// date, or only its year.
    private var isUpcoming: Bool {
        if let isOut { return !isOut }
        return releaseDate.map { ReleaseDateText.isUpcoming($0) } ?? true
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
                onOpenVolume: onOpenVolume,
                onOpenLacking: onOpenLacking
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
    /// First in the row: white, its label beside its icon.
    var isPrimary = false
    /// Asked before the action, which cannot be undone from the page; its
    /// destructive answer is the button's title. Nil acts at once.
    var confirmation: LocalizedStringKey? = nil
    let action: () async -> Void

    @State private var isInProgress = false
    @State private var confirms = false
    /// The slash taken off for a frame, so the tap draws it again.
    @State private var redraws = false

    /// The symbol drawn: a slashed one loses its slash for a frame on the tap.
    private var shownSymbol: String {
        redraws && systemImage.hasSuffix(".slash") ? String(systemImage.dropLast(6)) : systemImage
    }

    var body: some View {
        Button {
            guard !isInProgress else { return }
            if confirmation != nil { confirms = true } else { run() }
        } label: {
            if isPrimary {
                HStack(spacing: 8) {
                    if isInProgress {
                        ProgressView()
                    } else {
                        Image(systemName: shownSymbol)
                            .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp)))
                    }
                    Text(title)
                }
                .font(.headline)
                .lineLimit(1)
                .fixedSize()
            } else {
                Group {
                    if isInProgress {
                        ProgressView()
                    } else {
                        Image(systemName: shownSymbol)
                            .font(.title3.weight(.medium))
                            .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp)))
                    }
                }
            }
        }
        .buttonStyle(isPrimary
            ? ActionButtonStyle(fill: .white, height: side, isRaised: true)
            : ActionButtonStyle(fill: .glass, shape: .circle, height: side))
        .accessibilityLabel(Text(title))
        // Attached to the button, as the bell's: the dialog rises from it.
        .confirmationDialog(confirmation ?? "", isPresented: $confirms, titleVisibility: .visible) {
            Button(title, role: .destructive) { run() }
                .accessibilityIdentifier("unowned-confirm-remove")
            Button("Annuler", role: .cancel) {}
        }
    }

    private func run() {
        redraws = true
        Task {
            try? await Task.sleep(for: .milliseconds(40))
            withAnimation(.snappy) { redraws = false }
        }
        isInProgress = true
        Task {
            await action()
            isInProgress = false
        }
    }
}

#Preview("Volume announced") {
    NavigationStack {
        UnownedBookPage(
            book: DiscoveryVolume.preview.book(of: DiscoveryVolume.preview.volume.release.describedForPreview),
            releaseDate: Calendar.current.date(byAdding: .day, value: 79, to: .now)!
                .formatted(.iso8601.year().month().day()),
            isDescribing: false,
            store: UnownedBookStore(url: URL(string: "https://www.amazon.fr")!, isAudible: false),
            isAlerted: true,
            isAdded: false,
            sagaName: "Dungeon Crawler Carl",
            sagaVolumes: [.missing(key: "dcc-8", number: 8, title: "Le Livre du Carnage", forthcoming: true, date: "2026-11-05")]
        ) {}
    }
}

#Preview("Recording awaited") {
    NavigationStack {
        UnownedBookPage(
            book: AwaitedEdition.preview.release.describedForPreview.book(id: "awaited-preview"),
            releaseDate: AwaitedEdition.preview.date,
            isDescribing: true,
            store: UnownedBookStore(url: URL(string: "https://www.audible.fr")!, isAudible: true),
            isAlerted: true,
            bellConfirmation: BellConfirmation(
                title: "Ne plus suivre ce livre ?",
                message: "Vous ne serez plus prévenu de sa sortie.",
                action: "Ne plus suivre"
            )
        ) {}
    }
}
