import SwiftUI

/// Découvrir's line of the month's discoveries: every cover of the month's
/// selection, bare, as the other lines — or, while the selection is being
/// made, five covers still blank under "Recherche de vos découvertes…", and
/// once it ran out, the heading alone saying when the next ones come.
struct DiscoveriesSummaryRow: View {
    let line: DiscoveriesLine
    let width: CGFloat
    let onOpen: (Suggestion) -> Void

    var body: some View {
        switch line {
        case .shown(let discoveries):
            DiscoverSummaryRow(
                title: "\(discoveries.title)",
                systemImage: "sparkles",
                tint: .purple,
                line: String(localized: "D’après vos préférences")
            ) {
                ForEach(discoveries.suggestions) { suggestion in
                    Button { onOpen(suggestion) } label: {
                        CoverTile(book: suggestion.cover, caption: "", width: width)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("discover-suggestion")
                }
            }
            .accessibilityIdentifier("discover-discoveries")
        case .searching(let month):
            DiscoverSummaryRow(
                title: "\(MonthlyDiscoveries.title(month: month))",
                systemImage: "sparkles",
                tint: .purple,
                line: String(localized: "Recherche de vos découvertes…")
            ) {
                ForEach(0..<5, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                        .frame(width: width, height: width * 1.5)
                }
                .phaseAnimator([0.45, 1]) { content, opacity in
                    content.opacity(opacity)
                } animation: { _ in .easeInOut(duration: 0.9) }
            }
            .accessibilityIdentifier("discover-discoveries-searching")
        case .ranOut(let discoveries):
            // The heading alone: a month that ran out takes no more room than
            // it needs.
            DiscoverSummaryRow(
                title: "\(discoveries.title)",
                systemImage: "sparkles",
                tint: .purple,
                line: discoveries.nextLine
            )
            .accessibilityIdentifier("discover-discoveries-ran-out")
        }
    }
}

/// A suggestion's page: the standard book page — its header, its description
/// once written — with why it was chosen, the reader's books it was drawn
/// from under it. The "+" holds every action: add it, await it, or say "Pas
/// intéressé". Each closes the page and lets the next suggestion in.
struct SuggestionView: View {
    let suggestion: Suggestion
    /// The suggestion left the line: added, awaited or dismissed.
    var onDone: (SuggestionOutcome) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var describer = ReleaseDescriber.live()
    @State private var openReference: SuggestionReference?

    /// The suggestion once described, as a book's page draws it.
    private var shown: Book { suggestion.cover.described(by: describer.description) }

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
                    Button { openReference = reference } label: {
                        referenceRow(reference)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("suggestion-reference")
                }
            }
            ReleaseDescriptionSections(isDescribing: describer.isDescribing, synopsis: shown.synopsis)
            if suggestion.title != suggestion.originalTitle {
                Section {
                    LabeledContent("Titre original") {
                        Text(suggestion.originalTitle)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .labelStyle(.row)
        .task { await describer.describe(suggestion.seed) }
        .navigationTitle(Text("Découverte"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                notForMeMenu
            }
            ToolbarItem(placement: .primaryAction) {
                actionsMenu
            }
        }
        .sheet(item: $openReference) { reference in
            BookView(bookId: reference.bookId)
        }
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

    /// "+": on the pile, or awaited in each format its edition is not out and
    /// not awaited yet in, as a book's page offers it.
    private var actionsMenu: some View {
        Menu {
            Button("Ajouter", systemImage: "books.vertical") {
                Task { await add(status: .toRead) }
                close(.added)
            }
            .accessibilityIdentifier("suggestion-add")
            ForEach(suggestion.awaitableFormats) { format in
                Button(
                    format.awaitLabel,
                    systemImage: format == .audiobook ? "headphones" : "character.book.closed"
                ) {
                    Task { await awaitEdition(format) }
                    close(.awaited)
                }
                .accessibilityIdentifier("suggestion-await-\(format.rawValue)")
            }
        } label: {
            Label("Ajouter", systemImage: "plus")
                .labelStyle(.iconOnly)
        }
        .accessibilityIdentifier("suggestion-menu")
    }

    /// Beside the "+": the two ways of saying no — read already, which puts
    /// it on the shelf as read, or not interested, which is told to the model.
    private var notForMeMenu: some View {
        Menu {
            Button("Déjà lu", systemImage: "checkmark.circle") {
                Task { await add(status: .read) }
                close(.added)
            }
            .accessibilityIdentifier("suggestion-already-read")
            Button("Pas intéressé", systemImage: "eye.slash", role: .destructive) {
                close(.dismissed)
            }
            .accessibilityIdentifier("suggestion-dismiss")
        } label: {
            Label("Pas pour moi", systemImage: "hand.thumbsdown")
                .labelStyle(.iconOnly)
        }
        .accessibilityIdentifier("suggestion-not-for-me")
    }

    private func close(_ outcome: SuggestionOutcome) {
        onDone(outcome)
        dismiss()
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

    /// Puts it on the shelf — on the pile, or read already — in the format the
    /// line is drawn in, under its title in the app's language. The page is
    /// closed by then, so a failure is reported rather than shown.
    private func add(status: ReadingStatus) async {
        var draft = suggestion.draft
        draft.title = suggestion.title
        draft.language = nil
        draft.coverURL = suggestion.coverURL
        draft.format = suggestion.format == .audiobook ? .audiobook : .book
        if draft.format == .audiobook { draft.media = [] }
        draft.status = status
        do {
            _ = try await BookAddition.add(draft, source: .discover)
        } catch {
            _ = reportError(error)
        }
    }

    /// Awaits its edition in the app's language, in this format.
    private func awaitEdition(_ format: ReleaseFormat) async {
        do {
            _ = try await AwaitedAPI.awaitScanned(suggestion.draft, format: format)
        } catch {
            _ = reportError(error)
        }
    }
}

/// What took a suggestion off the line.
enum SuggestionOutcome {
    case added
    case awaited
    case dismissed
}

#Preview("Page") {
    NavigationStack {
        SuggestionView(suggestion: .preview)
    }
}
