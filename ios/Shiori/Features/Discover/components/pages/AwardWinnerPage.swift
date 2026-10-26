import SwiftUI

/// Everything an award winner's page can ask for.
enum AwardWinnerAction {
    case close
    /// On the pile.
    case add
    /// Its edition awaited in the app's language, in this format.
    case awaitEdition(ReleaseFormat)
}

/// One winner, opened from the strip, drawn as a volume announced is: where
/// its edition stands under the author, the store's tag once one sells it,
/// the prizes it won and the title it won under. The "+" opens a menu: put it
/// on the pile, or await its edition in the app's language, as a book seen in
/// a shop is awaited from its scan.
struct AwardWinnerPage: View {
    let winner: AwardWinner
    /// The winner once described, as a book's page draws it.
    let shown: Book
    let isDescribing: Bool
    /// False when the page is pushed: Back closes it, not a Close button.
    var showsClose = true
    let onAction: (AwardWinnerAction) async -> Void

    var body: some View {
        List {
            BookHeaderSection(
                book: shown,
                state: state,
                releaseDate: winner.state == .announced ? winner.date : nil,
                isAwaited: winner.awaitedEditionId != nil,
                storeLink: winner.storeURL.map {
                    .init(name: winner.format.storeName, url: $0, tint: winner.format.storeTint)
                },
                tag: Label {
                    Text(verbatim: winner.awardsLine)
                } icon: {
                    Image(systemName: "trophy")
                }
            )
            ReleaseDescriptionSections(isDescribing: isDescribing, synopsis: shown.synopsis)
            if winner.title != winner.originalTitle {
                Section {
                    LabeledContent("Titre original") {
                        Text(winner.originalTitle)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .generatingPill(isDescribing)
        .labelStyle(.row)
        .navigationTitle(Text(verbatim: winner.mentions.first?.award.shortName ?? ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsClose {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) { act(.close) }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                addMenu
            }
        }
    }

    /// The page closes at once on any of these: nothing to wait for here.
    private func act(_ action: AwardWinnerAction) {
        Task { await onAction(action) }
    }

    /// "+": on the pile, or awaited in each format its edition is not out
    /// and not awaited yet in, as a book's page offers it.
    private var addMenu: some View {
        Menu {
            Button("Ajouter", systemImage: "books.vertical") { act(.add) }
                .accessibilityIdentifier("award-winner-add")
            ForEach(winner.awaitableFormats) { format in
                Button(
                    format.awaitLabel,
                    systemImage: format == .audiobook ? "headphones" : "character.book.closed"
                ) {
                    act(.awaitEdition(format))
                }
                .accessibilityIdentifier("award-winner-await-\(format.rawValue)")
            }
        } label: {
            Label("Ajouter", systemImage: "plus")
                .labelStyle(.iconOnly)
        }
        .accessibilityIdentifier("award-winner-menu")
    }

    /// Said under the author: where the edition stands, once a reader awaited
    /// it and it was looked up; a day still to come is the calendar leaf's to
    /// say. Nothing is looked up for a winner nobody awaits.
    private var state: BookState? {
        if !winner.watched { return nil }
        if winner.state == .announced, let date = winner.date, ReleaseDateText.isUpcoming(date) { return nil }
        return BookState(text: winner.stateLine, tint: winner.stateTint)
    }
}

#Preview("Award winner") {
    NavigationStack {
        AwardWinnerPage(winner: .preview, shown: AwardWinner.preview.cover, isDescribing: false) { _ in }
    }
}

#Preview("Goncourt") {
    NavigationStack {
        AwardWinnerPage(
            winner: .goncourtPreview,
            shown: AwardWinner.goncourtPreview.cover,
            isDescribing: false
        ) { _ in }
    }
}

#Preview("Describing") {
    NavigationStack {
        AwardWinnerPage(winner: .preview, shown: AwardWinner.preview.cover, isDescribing: true) { _ in }
    }
}
