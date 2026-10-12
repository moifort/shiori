import SwiftUI

/// Découvrir's strip of the latest award winners the reader does not hold,
/// drawn as the editions awaited are: covers that scroll sideways, the prize
/// and its year under each.
struct AwardWinnersStrip: View {
    let winners: [AwardWinner]
    let onTapped: (AwardWinner) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(winners) { winner in
                    AwardWinnerTile(winner: winner) { onTapped(winner) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .listRowInsets(EdgeInsets())
    }
}

/// One winner, as the strip and Découvrir's "Prix littéraires" page draw it.
struct AwardWinnerTile: View {
    let winner: AwardWinner
    var width: CGFloat = 84
    let onTapped: () -> Void

    var body: some View {
        Button(action: onTapped) {
            CoverTile(book: winner.cover, caption: winner.caption, width: width, captionTruncation: .middle)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("discover-award-tile")
    }
}

/// One winner, opened from the strip, drawn as a volume
/// announced is: where its edition stands under the author, the store's tag
/// once one sells it, the prizes it won and the title it won under. The "+"
/// opens a menu: put it on the pile, or await its edition in the app's
/// language, as a book seen in a shop is awaited from its scan. Either closes
/// the page at once; the server is told behind it.
struct AwardWinnerView: View {
    let winner: AwardWinner

    @Environment(\.dismiss) private var dismiss
    @State private var describer = ReleaseDescriber()

    /// The winner once described, as a book's page draws it.
    private var shown: Book { winner.cover.described(by: describer.description) }

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
            ReleaseDescriptionSections(describer: describer, synopsis: shown.synopsis)
            if winner.title != winner.originalTitle {
                Section {
                    LabeledContent("Titre original") {
                        Text(winner.originalTitle)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .labelStyle(.row)
        .task { await describer.describe(winner.seed) }
        .navigationTitle(Text(verbatim: winner.mentions.first?.award.shortName ?? ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                addMenu
            }
        }
    }

    /// "+": on the pile, or awaited in each format its edition is not out
    /// and not awaited yet in, as a book's page offers it.
    private var addMenu: some View {
        Menu {
            Button("Ajouter", systemImage: "books.vertical") {
                Task { await add() }
                dismiss()
            }
            .accessibilityIdentifier("award-winner-add")
            ForEach(winner.awaitableFormats) { format in
                Button(
                    format.awaitLabel,
                    systemImage: format == .audiobook ? "headphones" : "character.book.closed"
                ) {
                    Task { await awaitEdition(format) }
                    dismiss()
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

    /// Puts it on the pile: the edition found when there is one, in the app's
    /// language, else the title it won under. The page is closed by then, so a
    /// failure is reported rather than shown.
    private func add() async {
        var draft = winner.draft
        if winner.state != .unannounced {
            draft.title = winner.title
            draft.language = nil
            draft.coverURL = winner.coverURL
        }
        draft.format = winner.format == .audiobook ? .audiobook : .book
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
            _ = try await AwaitedAPI.awaitScanned(winner.draft, format: format)
        } catch {
            _ = reportError(error)
        }
    }
}

extension AwardWinner {
    /// What the model is told: the edition found in the app's language, else
    /// the novel as it won.
    var seed: ReleaseSeed {
        ReleaseSeed(
            title: title,
            authors: authors,
            format: format == .audiobook ? .audiobook : .book,
            language: state == .unannounced ? originalLanguage : nil,
            releasedOn: date,
            coverURL: coverURL
        )
    }
}

extension AwardWinner {
    /// A winner in English nobody awaited yet: both formats left to await.
    static let preview = AwardWinner(
        id: "the-buffalo-hunter-hunter--stephen-graham-jones",
        format: .book,
        title: "The Buffalo Hunter Hunter",
        originalTitle: "The Buffalo Hunter Hunter",
        originalLanguage: .en,
        authors: ["Stephen Graham Jones"],
        mentions: [AwardMention(award: .nebula, year: 2026)],
        state: .unannounced,
        watched: false,
        date: nil,
        coverURL: nil,
        storeURL: nil,
        awaitableFormats: [.book, .audiobook],
        awaitedEditionId: nil
    )
}

#Preview("Award winner") {
    NavigationStack {
        AwardWinnerView(winner: .preview)
    }
}
