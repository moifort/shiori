import SwiftUI

/// A suggestion's page: the standard book page — its header, its description
/// once written — with why it was chosen, the reader's books it was drawn
/// from under it. The "+" holds every action: add it, await it, or say "Pas
/// intéressé". Each closes the page and lets the next suggestion in.
struct SuggestionView: View {
    let suggestion: Suggestion
    /// The suggestion left the line: added, awaited or dismissed.
    var onDone: (SuggestionOutcome) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var describer = ReleaseDescriber()
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
            ReleaseDescriptionSections(describer: describer, synopsis: shown.synopsis)
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
                actionsMenu
            }
        }
        .sheet(item: $openReference) { reference in
            BookView(bookId: reference.bookId)
        }
    }

    /// A reference: the book's or saga's name, then its mark — the heart or
    /// the stars, "série" when they are the saga's.
    private func referenceRow(_ reference: SuggestionReference) -> some View {
        HStack(spacing: 10) {
            Image(systemName: reference.seriesId != nil ? "books.vertical" : "book.closed")
                .foregroundStyle(.secondary)
            Text(reference.title)
                .lineLimit(1)
            Spacer(minLength: 8)
            if reference.viaSeries {
                Text("série")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            OpinionMark(rating: reference.rating, isFavorite: reference.favorite, font: .caption)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(.rect)
    }

    /// "+": on the pile, awaited in each format its edition is not out and not
    /// awaited yet in, or "Pas intéressé", as a book's page offers it.
    private var actionsMenu: some View {
        Menu {
            Button("Ajouter", systemImage: "books.vertical") {
                Task { await add() }
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
            Divider()
            Button("Pas intéressé", systemImage: "eye.slash", role: .destructive) {
                close(.dismissed)
            }
            .tint(.red)
            .accessibilityIdentifier("suggestion-dismiss")
        } label: {
            Label("Ajouter", systemImage: "plus")
                .labelStyle(.iconOnly)
        }
        .accessibilityIdentifier("suggestion-menu")
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

    /// Puts it on the pile, in the format the line is drawn in, under its
    /// title in the app's language. The page is closed by then, so a failure
    /// is reported rather than shown.
    private func add() async {
        var draft = suggestion.draft
        draft.title = suggestion.title
        draft.language = nil
        draft.coverURL = suggestion.coverURL
        draft.format = suggestion.format == .audiobook ? .audiobook : .book
        if draft.format == .audiobook { draft.media = [] }
        draft.status = .toRead
        do {
            _ = try await BookAPI.add(draft)
            track(.bookAdded(source: .discover))
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
