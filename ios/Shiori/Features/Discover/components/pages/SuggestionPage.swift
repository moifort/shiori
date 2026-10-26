import SwiftUI

/// Everything a suggestion's page can ask for.
enum SuggestionAction {
    case close
    /// On the shelf, on the pile or read already: the page closes behind it.
    case add(ReadingStatus)
    /// Its edition awaited in this format: the page closes behind it.
    case awaitEdition(ReleaseFormat)
    /// "Pas intéressé" or "Je n'aime pas": the page closes and the line lets
    /// the next one in.
    case dismiss(DismissalReason)
    /// One of the reader's own books it was drawn from.
    case openReference(SuggestionReference)
}

/// A suggestion's page, in the reader's own book page's grammar: the hero over
/// the cover's colours — where its edition stands on the detail line, the
/// "+" white where a book has its next step, the thumb that turns it down on
/// glass beside it — then why it was chosen, as a card over the colours of the
/// reader's books it draws on, the summary once written, and the facts as
/// tiles. The "+", in the hero and in the bar, adds it — on the pile or read
/// already — or awaits it; the thumb turns it down. Each closes the page and
/// lets the next suggestion in.
struct SuggestionPage: View {
    let suggestion: Suggestion
    /// The suggestion once described, as a book's page draws it.
    let shown: Book
    let isDescribing: Bool
    /// False when the page is pushed: Back closes it, not a Close button.
    var showsClose = true
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
                    addActions
                } label: {
                    Label("Ajouter", systemImage: "plus")
                        .labelStyle(.iconOnly)
                }
                .accessibilityIdentifier("suggestion-toolbar-add")
            }
        }
    }

    private func act(_ action: SuggestionAction) {
        Task { await onAction(action) }
    }

    // MARK: - Hero

    private var hero: some View {
        BookHero(
            book: shown,
            state: state,
            isAwaited: suggestion.awaitedEditionId != nil,
            showsLength: false
        ) {
            ScrollView(.horizontal) {
                heroButtons
                    .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .padding(.horizontal, -20)
        }
    }

    /// The "+" white, as a book's next step, and the thumb on glass beside it.
    private var heroButtons: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                addMenu
                notForMeMenu
            }
            .font(.subheadline.weight(.semibold))
            .controlSize(.regular)
        }
        .fixedSize()
    }

    /// On the pile, on the shelf as read, or awaited in each format its
    /// edition is not out and not awaited yet in, as a book's page offers it.
    private var addMenu: some View {
        Menu {
            addActions
        } label: {
            heroLabel("Ajouter", systemImage: "plus")
        }
        .menuStyle(.button)
        .buttonStyle(.glassProminent)
        .tint(.white)
        .foregroundStyle(.black)
        .accessibilityIdentifier("suggestion-menu")
    }

    /// What the "+" offers, in the hero and in the bar alike.
    private var addActions: some View {
        SuggestionAddActions(
            suggestion: suggestion,
            onAdd: { act(.add($0)) },
            onAwait: { act(.awaitEdition($0)) }
        )
    }

    /// The two ways of saying no, each told to the model — not their kind of
    /// book, which steers it clear of its like, or merely not for now.
    private var notForMeMenu: some View {
        Menu {
            Button("Je n'aime pas", systemImage: "hand.thumbsdown", role: .destructive) {
                act(.dismiss(.disliked))
            }
            .accessibilityIdentifier("suggestion-dislike")
            Button("Pas intéressé", systemImage: "eye.slash", role: .destructive) {
                act(.dismiss(.notInterested))
            }
            .accessibilityIdentifier("suggestion-dismiss")
        } label: {
            heroLabel("Pas pour moi", systemImage: "hand.thumbsdown")
        }
        .menuStyle(.button)
        .buttonStyle(.glass)
        .accessibilityIdentifier("suggestion-not-for-me")
    }

    /// Set as the reader's own hero sets its buttons: the symbol in the
    /// text's font, six points from it, one height.
    private func heroLabel(_ title: LocalizedStringKey, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .imageScale(.medium)
                .accessibilityHidden(true)
            Text(title)
        }
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 2)
        .frame(height: 24)
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
/// carousel: on the pile, on the shelf as read, or awaited in each format its
/// edition is not out and not awaited yet in.
struct SuggestionAddActions: View {
    let suggestion: Suggestion
    let onAdd: (ReadingStatus) -> Void
    let onAwait: (ReleaseFormat) -> Void

    var body: some View {
        Button("Ajouter", systemImage: "books.vertical") { onAdd(.toRead) }
            .accessibilityIdentifier("suggestion-add")
        Button("Déjà lu", systemImage: "checkmark.circle") { onAdd(.read) }
            .accessibilityIdentifier("suggestion-already-read")
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
        SuggestionPage(suggestion: .preview, shown: Suggestion.preview.cover, isDescribing: true) { _ in }
    }
}

#Preview("Described") {
    NavigationStack {
        SuggestionPage(
            suggestion: .preview,
            shown: Suggestion.preview.cover.described(by: .preview),
            isDescribing: false
        ) { _ in }
    }
}
