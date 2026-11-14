import SwiftUI

/// Everything an award winner's page can ask for.
enum AwardWinnerAction {
    case close
    /// Another winner, from the row at the foot of the page.
    case openWinner(AwardWinner)
}

/// One winner, in the suggestion's page's grammar: the hero over the cover's
/// colours, the prize between its laurels over the title and the white
/// "Ajouter" and closed eye under it, then the summary once written, the facts
/// as tiles and the other winners as posters. The "+", in the hero and in the
/// bar, adds or awaits it; the eye turns it down or says it read. The page
/// stays open on the choice, which the same button takes back.
struct AwardWinnerPage: View {
    let winner: AwardWinner
    /// The winner once described, as a book's page draws it.
    let shown: Book
    /// The winners listed beside it.
    var others: [AwardWinner] = []
    let isDescribing: Bool
    /// False when the page is pushed: Back closes it, not a Close button.
    var showsClose = true
    let choices: DiscoveryChoices
    /// Asks the server, and says whether it took the choice.
    let onChoice: (AwardWinner, DiscoveryChoice) async -> Bool
    let onAction: (AwardWinnerAction) async -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                VStack(alignment: .leading, spacing: 28) {
                    synopsis
                    facts
                    otherWinners
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
                    ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) { act(.close) }
                }
            }
            // The hero's "+" again, within reach once it has scrolled away.
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    DiscoveryAddActions(item: winner) { choose($0, leaving: $1) }
                } label: {
                    Label("Ajouter", systemImage: "plus")
                        .labelStyle(.iconOnly)
                }
                .disabled(choices.marks[winner.id] != nil || choices.working[winner.id] != nil)
                .accessibilityIdentifier("award-winner-menu")
            }
        }
    }

    private func act(_ action: AwardWinnerAction) {
        Task { await onAction(action) }
    }

    private func choose(_ choice: DiscoveryChoice, leaving mark: DiscoveryMark) {
        choices.choose(choice, for: winner, from: .add, leaving: mark, ask: onChoice)
    }

    // MARK: - Hero

    private var hero: some View {
        BookHero(
            book: shown,
            state: state,
            stateTag: winner.watched && winner.state == .unannounced ? String(localized: "Pas annoncé") : nil,
            isAwaited: winner.awaitedEditionId != nil,
            overTitle: winner.mentions.first.map { AnyView(AwardLaurels(mention: $0)) }
        ) {
            HStack(spacing: 12) {
                DiscoveryButtons(item: winner, choices: choices, onChoice: onChoice, addsInFull: true)
            }
            .controlSize(.large)
        }
    }

    /// Said on the detail line: when an edition announced comes out, where it
    /// stands once a reader awaited it and it was looked up, else the year it
    /// came out.
    private var state: BookState? {
        if winner.state == .announced, let date = winner.date, ReleaseDateText.isUpcoming(date) {
            return .release(date)
        }
        if winner.watched {
            // Nothing announced is a tag, beside the format's.
            return winner.state == .unannounced ? nil : BookState(text: winner.stateLine, tint: winner.stateTint)
        }
        return shown.firstPublishedIn.map { BookState(text: String($0), tint: .secondary) }
    }

    // MARK: - Blocks

    /// The summary once the model wrote it; nothing while it writes, the bar
    /// saying so.
    @ViewBuilder private var synopsis: some View {
        if !isDescribing, let synopsis = shown.synopsis, !synopsis.isEmpty {
            BookSynopsisBlock(synopsis: synopsis)
        }
    }

    /// What it won and what it is, its title in its own language heading them
    /// when the edition translates it, and the store that sells it closing them.
    private var facts: some View {
        VStack(alignment: .leading, spacing: 12) {
            RowHeader(title: "Informations")
            FactGrid(groups: [FactGroup(tiles: originalTitleTile + prizeTiles + bookTiles)], links: storeLinks)
        }
    }

    private var originalTitleTile: [FactTile] {
        guard winner.title != winner.originalTitle else { return [] }
        return [FactTile(id: "originalTitle", title: "Titre original", value: winner.originalTitle, isWide: true)]
    }

    /// The prizes it won, then what the first crowns. Several take the width.
    private var prizeTiles: [FactTile] {
        guard let first = winner.mentions.first else { return [] }
        return [
            FactTile(id: "prize", title: "Prix", value: winner.mentionsLine, isWide: winner.mentions.count > 1),
            FactTile(id: "category", title: "Catégorie", value: first.award.categoryName),
        ]
    }

    /// The book's own facts, the ones the page's description fills in, and
    /// only once they are known.
    private var bookTiles: [FactTile] {
        let shownFacts = ["publisher", "pageCount", "duration", "genre"]
        return shown.readOnlyFactTiles
            .filter { shownFacts.contains($0.id) && $0.value != nil }
            .sorted { shownFacts.firstIndex(of: $0.id) ?? 0 < shownFacts.firstIndex(of: $1.id) ?? 0 }
    }

    private var storeLinks: [FactLink] {
        guard let url = winner.storeURL else { return [] }
        return switch winner.format {
        case .audiobook: [FactLink(id: "audible", title: "Écouter sur Audible", logo: "audible-logo", url: url)]
        case .book: [FactLink(id: "amazon", title: "Voir sur Amazon", logo: "amazon-logo", url: url)]
        }
    }

    @ViewBuilder private var otherWinners: some View {
        if !others.isEmpty {
            SeriesPosterRail(title: "Autres lauréats", items: others) { other in
                Button {
                    act(.openWinner(other))
                } label: {
                    PosterCover(book: other.cover, caption: other.caption)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("award-winner-other")
            }
        }
    }
}

#Preview("Award winner") {
    NavigationStack {
        AwardWinnerPage(
            winner: .preview,
            shown: AwardWinner.preview.release.describedForPreview.book(id: "award-preview"),
            others: [.goncourtPreview],
            isDescribing: false,
            choices: DiscoveryChoices(),
            onChoice: { _, _ in true }
        ) { _ in }
    }
}

#Preview("Goncourt") {
    NavigationStack {
        AwardWinnerPage(
            winner: .goncourtPreview,
            shown: AwardWinner.goncourtPreview.cover,
            isDescribing: false,
            choices: DiscoveryChoices(),
            onChoice: { _, _ in true }
        ) { _ in }
    }
}

#Preview("Describing") {
    NavigationStack {
        AwardWinnerPage(
            winner: .preview,
            shown: AwardWinner.preview.cover,
            isDescribing: true,
            choices: DiscoveryChoices(),
            onChoice: { _, _ in true }
        ) { _ in }
    }
}
