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

/// A suggestion's page: the standard book page — its header, its description
/// once written — with why it was chosen, the reader's books it was drawn
/// from under it. The "+" adds it — on the pile or read already — or awaits
/// it; the thumb turns it down. Each closes the page and lets the next
/// suggestion in.
struct SuggestionPage: View {
    let suggestion: Suggestion
    /// The suggestion once described, as a book's page draws it.
    let shown: Book
    let isDescribing: Bool
    /// False when the page is pushed: Back closes it, not a Close button.
    var showsClose = true
    let onAction: (SuggestionAction) async -> Void

    var body: some View {
        List {
            BookHeaderSection(
                book: shown,
                state: state,
                releaseDate: suggestion.state == .announced ? suggestion.date : nil,
                isAwaited: suggestion.awaitedEditionId != nil,
                storeLink: suggestion.storeURL.map {
                    .init(name: suggestion.format.storeName, url: $0, tint: suggestion.format.storeTint)
                }
            )
            // Why, then the reader's own books it draws on, each opening its
            // page.
            Section("Pourquoi ce livre") {
                Text(suggestion.reason)
                    .accessibilityIdentifier("suggestion-reason")
                ForEach(suggestion.references) { reference in
                    Button { act(.openReference(reference)) } label: {
                        referenceRow(reference)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("suggestion-reference")
                }
            }
            ReleaseDescriptionSections(isDescribing: isDescribing, synopsis: shown.synopsis)
            if suggestion.title != suggestion.originalTitle {
                Section {
                    LabeledContent("Titre original") {
                        Text(suggestion.originalTitle)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .generatingInBar(isDescribing ? "L'IA complète la fiche" : nil)
        .labelStyle(.row)
        .navigationTitle(Text("Découverte"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsClose {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) { act(.close) }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                notForMeMenu
            }
            ToolbarItem(placement: .primaryAction) {
                actionsMenu
            }
        }
    }

    private func act(_ action: SuggestionAction) {
        Task { await onAction(action) }
    }

    /// A reference: the reader's own cover of it, its name, then its mark —
    /// the heart or the stars, the saga's when the book has none.
    private func referenceRow(_ reference: SuggestionReference) -> some View {
        HStack(spacing: 12) {
            BookCover(book: reference.cover, width: 32, showsFormatBadge: false)
            Text(reference.title)
                .lineLimit(2)
            Spacer(minLength: 8)
            OpinionMark(rating: reference.rating, isFavorite: reference.favorite, font: .caption)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(.rect)
    }

    /// "+": on the pile, on the shelf as read, or awaited in each format its
    /// edition is not out and not awaited yet in, as a book's page offers it.
    private var actionsMenu: some View {
        Menu {
            Button("Ajouter", systemImage: "books.vertical") { act(.add(.toRead)) }
                .accessibilityIdentifier("suggestion-add")
            Button("Déjà lu", systemImage: "checkmark.circle") { act(.add(.read)) }
                .accessibilityIdentifier("suggestion-already-read")
            ForEach(suggestion.awaitableFormats) { format in
                Button(
                    format.awaitLabel,
                    systemImage: format == .audiobook ? "headphones" : "character.book.closed"
                ) {
                    act(.awaitEdition(format))
                }
                .accessibilityIdentifier("suggestion-await-\(format.rawValue)")
            }
        } label: {
            Label("Ajouter", systemImage: "plus")
                .labelStyle(.iconOnly)
        }
        .accessibilityIdentifier("suggestion-menu")
    }

    /// Beside the "+": the two ways of saying no, each told to the model —
    /// not their kind of book, which steers it clear of its like, or merely
    /// not for now.
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
            Label("Pas pour moi", systemImage: "hand.thumbsdown")
                .labelStyle(.iconOnly)
        }
        .accessibilityIdentifier("suggestion-not-for-me")
    }

    /// Said under the author: where the edition stands, once a reader awaited
    /// it and it was looked up.
    private var state: BookState? {
        if !suggestion.watched { return nil }
        if suggestion.state == .announced, let date = suggestion.date, ReleaseDateText.isUpcoming(date) {
            return nil
        }
        return BookState(text: suggestion.stateLine, tint: suggestion.stateTint)
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
