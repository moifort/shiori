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

/// Every award of a genre in full: one section per award, its winners the
/// reader does not hold, the newest first, and how many of them they read.
/// The capsule on top switches to another genre the reader reads enough.
struct AwardsListView: View {
    let format: ReleaseFormat
    @State var shelf: AwardShelf

    @Environment(\.dismiss) private var dismiss
    @State private var opened: AwardWinner?
    @State private var isSwitching = false

    var body: some View {
        List {
            if shelf.genres.count > 1 {
                Section {
                    Picker("Genre", selection: genreBinding) {
                        ForEach(shelf.genres, id: \.self) { genre in
                            Text(genre.label).tag(genre)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(isSwitching)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            ForEach(shelf.awards) { list in
                Section {
                    if list.winners.isEmpty {
                        Text("Vous avez tous ses lauréats.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(list.winners) { winner in
                        Button { opened = winner } label: { AwardWinnerRow(winner: winner, award: list.award) }
                            .tint(.primary)
                            .accessibilityIdentifier("award-winner-row")
                    }
                } header: {
                    Text(list.award.name)
                } footer: {
                    Text("\(list.readCount) lauréats lus sur \(list.total)")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Prix littéraires")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) { dismiss() }
            }
        }
        .sheet(item: $opened) { winner in
            NavigationStack { AwardWinnerView(winner: winner) }
        }
    }

    private var genreBinding: Binding<BookGenre> {
        Binding(
            get: { shelf.genre },
            set: { genre in Task { await switchTo(genre) } }
        )
    }

    /// Asks for the other genre; the list stays as it is when the server
    /// does not answer.
    private func switchTo(_ genre: BookGenre) async {
        isSwitching = true
        defer { isSwitching = false }
        do {
            if let found = try await AwardsAPI.shelf(format: format, genre: genre) {
                withAnimation(.smooth) { shelf = found }
            }
        } catch {
            _ = reportError(error)
        }
    }
}

/// A winner on the full list: its cover, the year it won this award, its
/// title and author, and where its edition stands.
struct AwardWinnerRow: View {
    let winner: AwardWinner
    let award: LiteraryAward

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            BookCover(book: winner.cover)
            VStack(alignment: .leading, spacing: 3) {
                if let year = winner.mentions.first(where: { $0.award == award })?.year {
                    Text(verbatim: String(year))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(winner.title)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                Text(winner.authors.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(winner.stateLine)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(winner.stateTint)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 8)
        }
        .padding(.vertical, 4)
    }
}

/// One winner, opened from the strip or the full list, drawn as a volume
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

    var body: some View {
        List {
            BookHeaderSection(
                book: winner.cover,
                state: state,
                releaseDate: winner.state == .announced ? winner.date : nil,
                isAwaited: awaited || winner.awaitedEditionId != nil,
                storeLink: winner.storeURL.map {
                    .init(name: winner.format.storeName, url: $0, tint: winner.format.storeTint)
                }
            )
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
