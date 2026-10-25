import SwiftUI

/// Everything a friend's book page can ask for.
enum FriendBookAction {
    /// The saga the book belongs to, pushed inside the sheet.
    case openSeries
    /// An author's page, from the hero's author line.
    case openAuthor(AuthorDestination)
    /// An edition awaited, opened as Découvrir opens it.
    case openAwaited(AwaitedEdition)
    case stopAwaiting(AwaitedEdition)
    /// Onto the reader's own shelf, as the hero's first button offers it.
    case add(CopiedStatus, BookFormat)
    case awaitEdition(ReleaseFormat)
}

/// What a friend's book page draws once the book is known: the reader's own
/// book page, read-only. The same hero over the cover's colours — the friend
/// named on the detail line with where they stand, their monogram in the
/// corner as an account's, the way onto the
/// reader's shelf where their own book has its next step, and the friend's
/// stars and heart on glass beside it — then the same blocks: the summary,
/// the facts as tiles, the editions awaited, the saga. Nothing can be corrected here, so no tile answers a
/// tap; the friend's own remarks stay private and never reach this page.
struct FriendBookPage: View {
    let entry: FriendBook
    /// The friend whose shelf it is: their saga opens as they hold it.
    let friendId: String
    let friendName: String
    /// What the reader just did with it from the hero's first button.
    let added: CopiedStatus?
    let awaited: [AwaitedEdition]
    /// The formats the reader may take the book in.
    var formats: [BookFormat] = []
    /// The editions the reader may await from here.
    var awaitable: [ReleaseFormat] = []
    let onAction: (FriendBookAction) async -> Void

    private var book: Book { entry.book }
    private var owned: Bool { entry.inLibrary || added != nil }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                VStack(alignment: .leading, spacing: 28) {
                    synopsis
                    facts
                    awaitedBlock
                    series
                    comments
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
        }
        // The bar's buttons float over the page as it scrolls, no frosted
        // band behind them: the page runs under them as under the TV app's.
        .scrollEdgeEffectHidden(true, for: .top)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Hero

    private var hero: some View {
        BookHero(
            book: book,
            state: friendState,
            isAwaited: !awaited.isEmpty,
            showsLength: false,
            onOpenAuthor: { author in Task { await onAction(.openAuthor(author)) } }
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

    /// Where the friend stands, said as a sentence about them: "Camille l'a lu
    /// le 15 octobre", "Camille le lit depuis 3 jours", "Dans la pile de
    /// Camille" — heard rather than read for a recording.
    private var friendState: BookState {
        let tint = book.status.tint
        let heard = book.format == .audiobook
        let name = friendName
        let text: String
        switch book.status {
        case .read:
            if let finished = book.finishedAt {
                let day = finished.formatted(.dateTime.day().month(.wide))
                text = heard
                    ? String(localized: "\(name) l'a écouté le \(day)")
                    : String(localized: "\(name) l'a lu le \(day)")
            } else {
                text = heard ? String(localized: "\(name) l'a écouté") : String(localized: "\(name) l'a lu")
            }
        case .reading:
            guard let started = book.startedAt else {
                text = heard ? String(localized: "\(name) l'écoute en ce moment") : String(localized: "\(name) le lit en ce moment")
                break
            }
            let days = started.daysAgo()
            if days == 0 {
                text = String(localized: "\(name) l'a commencé aujourd'hui")
            } else if days == 1 {
                text = heard ? String(localized: "\(name) l'écoute depuis hier") : String(localized: "\(name) le lit depuis hier")
            } else {
                text = heard
                    ? String(localized: "\(name) l'écoute depuis \(days) jours")
                    : String(localized: "\(name) le lit depuis \(days) jours")
            }
        case .toRead:
            text = String(localized: "Dans la pile de \(name)")
        case .dropped:
            text = String(localized: "\(name) l'a abandonné")
        }
        return BookState(text: text, tint: tint)
    }

    /// The way onto the reader's shelf white, then what the friend made of
    /// the book on glass — their stars, their heart — set as the reader's own
    /// hero sets its rating: same font, same height, nothing to tap.
    private var heroButtons: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                FriendBookAddMenu(
                    formats: formats,
                    owned: owned,
                    awaitable: awaitable,
                    onAdd: { status, format in await onAction(.add(status, format)) },
                    onAwait: { format in Task { await onAction(.awaitEdition(format)) } }
                )
                if let rating = book.rating {
                    glassChip {
                        RatingStars(rating: rating, font: .footnote, monochrome: true)
                    }
                    .accessibilityLabel(Text("Noté \(Int(rating)) sur 5 par \(friendName)"))
                    .accessibilityIdentifier("friend-book-rating")
                }
                // The heart alone: with its words the row ran past the
                // width, and a red heart says it.
                if book.favorite {
                    glassChip {
                        // A full red: the hero's dark appearance lightens
                        // the system red to a pink on glass.
                        Image(systemName: "heart.fill")
                            .foregroundStyle(Color(red: 0.93, green: 0.1, blue: 0.15))
                    }
                    .accessibilityLabel(Text("Coup de cœur de \(friendName)"))
                    .accessibilityIdentifier("friend-book-favorite")
                }
            }
            .font(.subheadline.weight(.semibold))
            .controlSize(.regular)
        }
        .fixedSize()
    }

    /// A fact on glass beside the hero's button, at the button's own size.
    private func glassChip(@ViewBuilder _ content: () -> some View) -> some View {
        content()
            .lineLimit(1)
            .fixedSize()
            .frame(height: 24)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .capsule)
    }

    // MARK: - Blocks

    @ViewBuilder private var synopsis: some View {
        if let synopsis = book.synopsis, !synopsis.isEmpty {
            BookSynopsisBlock(synopsis: synopsis)
        }
    }

    /// What the book is, two tiles to a row. Not the friend's days: the hero
    /// says when they read it, and the rest is theirs.
    private var facts: some View {
        VStack(alignment: .leading, spacing: 12) {
            RowHeader(title: "Informations")
            FactGrid(groups: [FactGroup(tiles: book.readOnlyFactTiles)], links: book.storeFactLinks)
        }
    }

    /// The editions of it the reader awaits, as their own page lists them.
    @ViewBuilder private var awaitedBlock: some View {
        let found = awaited.filter { $0.state != .unannounced }
        if !found.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                RowHeader(title: "Éditions guettées")
                VStack(spacing: 0) {
                    ForEach(found) { edition in
                        Button { Task { await onAction(.openAwaited(edition)) } } label: {
                            AwaitedEditionReleaseRow(edition: edition)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Ne plus suivre", systemImage: "bell.slash", role: .destructive) {
                                Task { await onAction(.stopAwaiting(edition)) }
                            }
                        }
                        .accessibilityIdentifier("friend-book-awaited-\(edition.format.rawValue)")
                        if edition.id != found.last?.id { Divider().padding(.leading, 14) }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
            }
        }
    }

    /// The friend's words on the book, as the reader's own page draws a
    /// recommender's: a grey bubble under their name, their initial beside
    /// it, as Messages signs a group's lines. Nothing when they wrote nothing.
    @ViewBuilder private var comments: some View {
        if let note = book.note, !note.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                RowHeader(title: "Commentaires")
                MessageBubble(text: note, sender: friendName)
                    .copyable(note)
                    .accessibilityIdentifier("friend-book-note")
            }
        }
    }

    /// The saga under its own name, this volume alone on the row: the
    /// friend's other volumes are the saga screen's, one tap away.
    @ViewBuilder private var series: some View {
        if let membership = book.series {
            SeriesVolumesRow(
                name: membership.name,
                volumes: [.owned(book)],
                currentId: book.id,
                onOpenSeries: { Task { await onAction(.openSeries) } },
                onOpenVolume: { _ in }
            )
        }
    }
}

#Preview("Friend's book held already") {
    NavigationStack {
        FriendBookPage(entry: .preview, friendId: "preview", friendName: "Camille", added: nil, awaited: []) { _ in }
    }
}

#Preview("With the friend's remarks") {
    var entry = FriendBook.preview
    entry.book.note = "La scène de l'auberge, au début, vaut le livre entier. Lis-le, tu vas adorer Kvothe."
    return NavigationStack {
        FriendBookPage(entry: entry, friendId: "preview", friendName: "Camille", added: nil, awaited: []) { _ in }
    }
}

#Preview("Not on the reader's shelf") {
    var entry = FriendBook.preview
    entry.inLibrary = false
    return NavigationStack {
        FriendBookPage(
            entry: entry, friendId: "preview", friendName: "Camille", added: nil, awaited: [],
            formats: [.book, .audiobook], awaitable: [.audiobook]
        ) { _ in }
    }
}
