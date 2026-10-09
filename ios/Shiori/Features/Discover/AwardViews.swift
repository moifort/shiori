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
                    Button { onTapped(winner) } label: {
                        CoverTile(
                            book: winner.cover,
                            caption: winner.caption,
                            showsTitle: false,
                            captionTint: winner.state == .available ? .green : nil
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("discover-award-tile")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .listRowInsets(EdgeInsets())
    }
}

/// One winner, opened from the strip, drawn as a volume
/// announced is: where its edition stands under the author, the store's tag
/// once one sells it, the prizes it won and the title it won under. "+" puts it
/// on the pile; "Guetter" awaits its edition in the app's language, as a
/// book seen in a shop is awaited from its scan.
struct AwardWinnerView: View {
    let winner: AwardWinner

    @Environment(\.dismiss) private var dismiss
    @State private var isAdding = false
    @State private var added = false
    @State private var isAwaiting = false
    @State private var awaited = false
    @State private var failure: String?
    @State private var describer = ReleaseDescriber()

    /// The winner once described, as a book's page draws it.
    private var shown: Book { winner.cover.described(by: describer.description) }

    var body: some View {
        List {
            BookHeaderSection(
                book: shown,
                state: state,
                releaseDate: winner.state == .announced ? winner.date : nil,
                isAwaited: awaited || winner.awaitedEditionId != nil,
                storeLink: winner.storeURL.map {
                    .init(name: winner.format.storeName, url: $0, tint: winner.format.storeTint)
                }
            )
            ReleaseDescriptionSections(describer: describer, synopsis: shown.synopsis)
            Section {
                ForEach(winner.mentions, id: \.self) { mention in
                    LabeledContent(mention.award.name) {
                        Text(verbatim: String(mention.year))
                    }
                }
                if winner.title != winner.originalTitle {
                    LabeledContent("Titre original") {
                        Text(winner.originalTitle)
                    }
                }
            } header: {
                Text("Récompenses")
            }
            if winner.awaitable && !awaited {
                Section {
                    Button(winner.format.awaitLabel, systemImage: "binoculars") {
                        Task { await awaitEdition() }
                    }
                    .disabled(isAwaiting)
                    .accessibilityIdentifier("award-winner-await")
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
                if isAdding {
                    ProgressView()
                } else {
                    Button("Ajouter à ma pile", systemImage: "plus") {
                        Task { await add() }
                    }
                    .disabled(added)
                    .accessibilityIdentifier("award-winner-add")
                }
            }
        }
        .alert(
            "Action impossible",
            isPresented: .init(get: { failure != nil }, set: { if !$0 { failure = nil } })
        ) {
            Button("OK", role: .cancel) { failure = nil }
        } message: {
            Text(failure ?? "")
        }
    }

    /// Said under the author: once added, where the edition stands; a day
    /// still to come is the calendar leaf's to say.
    private var state: BookState? {
        if added { return .addedToPile }
        if winner.state == .announced, let date = winner.date, ReleaseDateText.isUpcoming(date) { return nil }
        return BookState(text: winner.stateLine, tint: winner.stateTint)
    }

    /// Puts it on the pile: the edition found when there is one, in the app's
    /// language, else the title it won under.
    private func add() async {
        isAdding = true
        defer { isAdding = false }
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
            added = true
        } catch {
            failure = reportError(error)
        }
    }

    /// Awaits its edition in the app's language, in the format on screen.
    private func awaitEdition() async {
        isAwaiting = true
        defer { isAwaiting = false }
        do {
            _ = try await AwaitedAPI.awaitScanned(winner.draft, format: winner.format)
            awaited = true
        } catch {
            failure = reportError(error)
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
