import SwiftUI

/// Everything a suggestion's page can ask for.
enum SuggestionAction {
    case close
    /// One of the reader's own books it was drawn from.
    case openReference(SuggestionReference)
}

/// A suggestion's page, in the reader's own book page's grammar: the hero over
/// the cover's colours — where its edition stands on the detail line, the
/// home hero's "+" and closed eye under it — then why it was chosen, as a card over the colours of the
/// reader's books it draws on, the summary once written, and the facts as
/// tiles. The "+", in the hero and in the bar, adds or awaits it; the eye turns
/// it down or says it read. The page stays open on the choice, which the same
/// button takes back.
struct SuggestionPage: View {
    let suggestion: Suggestion
    /// The suggestion once described, as a book's page draws it.
    let shown: Book
    let isDescribing: Bool
    /// False when the page is pushed: Back closes it, not a Close button.
    var showsClose = true
    let choices: DiscoveryChoices
    /// Asks the server, and says whether it took the choice.
    let onChoice: (Suggestion, DiscoveryChoice) async -> Bool
    let onAction: (SuggestionAction) async -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                VStack(alignment: .leading, spacing: 28) {
                    SuggestionReasonCard(reason: suggestion.reason, references: suggestion.references) {
                        act(.openReference($0))
                    }
                    synopsis
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
                    SuggestionAddActions(
                        suggestion: suggestion,
                        onAdd: { choose(.add) },
                        onAwait: { choose(.await($0)) }
                    )
                } label: {
                    Label("Ajouter", systemImage: "plus")
                        .labelStyle(.iconOnly)
                }
                .disabled(choices.marks[suggestion.id] != nil || choices.working[suggestion.id] != nil)
                .accessibilityIdentifier("suggestion-toolbar-add")
            }
        }
    }

    private func act(_ action: SuggestionAction) {
        Task { await onAction(action) }
    }

    private func choose(_ choice: DiscoveryChoice) {
        choices.choose(choice, for: suggestion, from: .add, leaving: .added, ask: onChoice)
    }

    // MARK: - Hero

    private var hero: some View {
        BookHero(
            book: shown,
            state: state,
            isAwaited: suggestion.awaitedEditionId != nil,
            showsLength: false
        ) {
            HStack(spacing: 12) {
                DiscoveryButtons(suggestion: suggestion, choices: choices, onChoice: onChoice)
            }
            .controlSize(.large)
        }
    }

    /// Said on the detail line: when an edition announced comes out, or where
    /// it stands once a reader awaited it and it was looked up.
    private var state: BookState? {
        if suggestion.state == .announced, let date = suggestion.date, ReleaseDateText.isUpcoming(date) {
            return .release(date)
        }
        if !suggestion.watched { return nil }
        return BookState(text: suggestion.stateLine, tint: suggestion.stateTint)
    }

    // MARK: - Blocks

    /// The summary once the model wrote it; nothing while it writes, the bar
    /// saying so.
    @ViewBuilder private var synopsis: some View {
        if !isDescribing, let synopsis = shown.synopsis, !synopsis.isEmpty {
            BookSynopsisBlock(synopsis: synopsis)
        }
    }

    /// What the book is, as a book's page tiles it, its title in its own
    /// language heading them when the edition translates it, and the store
    /// that sells it closing them.
    private var facts: some View {
        VStack(alignment: .leading, spacing: 12) {
            RowHeader(title: "Informations")
            FactGrid(groups: [FactGroup(tiles: originalTitleTile + shown.readOnlyFactTiles)], links: storeLinks)
        }
    }

    private var originalTitleTile: [FactTile] {
        guard suggestion.title != suggestion.originalTitle else { return [] }
        return [FactTile(id: "originalTitle", title: "Titre original", value: suggestion.originalTitle, isWide: true)]
    }

    private var storeLinks: [FactLink] {
        guard let url = suggestion.storeURL else { return [] }
        return switch suggestion.format {
        case .audiobook: [FactLink(id: "audible", title: "Écouter sur Audible", logo: "audible-logo", url: url)]
        case .book: [FactLink(id: "amazon", title: "Voir sur Amazon", logo: "amazon-logo", url: url)]
        }
    }
}

/// What a suggestion's "+" offers, on its page and on the home screen's
/// carousel: on the pile, or awaited in each format its edition is not out and
/// not awaited yet in. "Déjà lu" is the eye's.
struct SuggestionAddActions: View {
    let suggestion: Suggestion
    let onAdd: () -> Void
    let onAwait: (ReleaseFormat) -> Void

    var body: some View {
        Button("Ajouter", systemImage: "books.vertical") { onAdd() }
            .accessibilityIdentifier("suggestion-add")
        ForEach(suggestion.awaitableFormats) { format in
            Button(
                format.awaitLabel,
                systemImage: format == .audiobook ? "headphones" : "character.book.closed"
            ) {
                onAwait(format)
            }
            .accessibilityIdentifier("suggestion-await-\(format.rawValue)")
        }
    }
}

#Preview("Describing") {
    NavigationStack {
        SuggestionPage(
            suggestion: .preview,
            shown: Suggestion.preview.cover,
            isDescribing: true,
            choices: DiscoveryChoices(),
            onChoice: { _, _ in true }
        ) { _ in }
    }
}

#Preview("Described") {
    NavigationStack {
        SuggestionPage(
            suggestion: .preview,
            shown: Suggestion.preview.cover.described(by: .preview),
            isDescribing: false,
            choices: DiscoveryChoices(),
            onChoice: { _, _ in true }
        ) { _ in }
    }
}
