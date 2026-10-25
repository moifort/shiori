import SwiftUI

/// One book's screen in the TV app's grammar: a hero over the cover's colours —
/// where the book stands, what it is, the next step and the rating on Liquid
/// Glass under the cover — then blocks on the page without cards around them:
/// the summary, the facts as tiles, the saga as a row of its volumes, and the
/// reader's own reading. Pure and previewable.
///
/// The hero's first button moves the book to its next state — started, read
/// — and a book read offers its rating and its comment instead; the full
/// choice of status is in the "…" menu, with sharing
/// and everything the page does not draw. A tap on a tile corrects that fact,
/// as a tap on a day of the reading corrects that day; "Modifier" opens the
/// whole form.
struct BookPage: View {
    let book: Book
    let isSaving: Bool
    let onSetStatus: (ReadingStatus) -> Void
    let onRate: () -> Void
    let onOpenSeries: () -> Void
    let onEdit: () -> Void
    let onEditGenre: () -> Void
    let onEditRecommendation: () -> Void
    let onEditNote: () -> Void
    let onEditField: (BookField) -> Void
    /// The volumes of its saga the reader holds, this one among them. Empty
    /// while they are on their way: the row then holds this volume alone.
    var seriesVolumes: [Book] = []
    var onOpenVolume: (Book) -> Void = { _ in }
    /// The editions of this book the reader awaits in the app's language.
    var awaited: [AwaitedEdition] = []
    var onOpenAwaited: (AwaitedEdition) -> Void = { _ in }
    var onStopAwaiting: (AwaitedEdition) -> Void = { _ in }
    /// A task the screen moved onto the second page of an unfolded iPhone Duo
    /// — the edit form — drawn there in place of the reading, beside the book
    /// it changes rather than over it.
    var secondPage: AnyView? = nil

    /// Bumped by "Remarques" when the reader already wrote some: the page
    /// holding them scrolls to them rather than opening the form again.
    @State private var noteRequest = 0
    private static let noteAnchor = "book-note-anchor"

    var body: some View {
        // On an unfolded iPhone Duo the book takes a page — the hero, what it
        // is, its saga — and the reader's own reading the other.
        TwoPages {
            page {
                hero
                blocks {
                    synopsis
                    facts
                    awaitedBlock
                    series
                }
            }
        } second: {
            if let secondPage {
                secondPage
            } else {
                page {
                    blocks { reading }
                        .padding(.top, 8)
                }
            }
        } single: {
            page {
                hero
                blocks {
                    synopsis
                    facts
                    awaitedBlock
                    series
                    reading
                }
            }
        }
    }

    // MARK: - Layout

    private func page(@ViewBuilder _ content: () -> some View) -> some View {
        let content = content()
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) { content }
            }
            // Only the page that holds the remarks has their anchor: on an
            // unfolded Duo the other one ignores the request.
            .onChange(of: noteRequest) {
                withAnimation(.smooth) { proxy.scrollTo(Self.noteAnchor, anchor: .center) }
            }
        }
        .background(Color(.systemGroupedBackground))
        .disabled(isSaving)
    }

    private func blocks(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 28) { content() }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 32)
    }

    // MARK: - Hero

    private var hero: some View {
        BookHero(book: book, state: .reading(of: book), isAwaited: !awaited.isEmpty) {
            // Sideways past the width, from edge to edge, rather than a
            // label cut or an icon dropped.
            ScrollView(.horizontal) {
                heroButtons
                    .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .padding(.horizontal, -20)
        }
        .sensoryFeedback(.success, trigger: book.status)
    }

    /// The next step white, the rating and the reader's remarks on glass, set
    /// as Apple Music sets "Lecture" and "Aléatoire": subheadline semibold,
    /// the symbol at the text's own size and weight, a tight gap between
    /// them, every button the same height. A book read waits for the reader's
    /// word on it, not for a next state: reading it again clears the day it
    /// was finished, a choice made in the menu, not here.
    private var heroButtons: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                if let step = NextStep(status: book.status) {
                    primaryButton(step)
                } else {
                    readButton
                }
                ratingButton(prominent: false)
                noteButton
            }
            .font(.subheadline.weight(.semibold))
            .controlSize(.regular)
        }
        .fixedSize()
    }

    /// The next step the book is waiting for.
    private func primaryButton(_ step: NextStep) -> some View {
        Button {
            onSetStatus(step.status)
        } label: {
            HeroButtonLabel(title: step.title, systemImage: step.systemImage)
        }
        .buttonStyle(.glassProminent)
        .tint(.white)
        .foregroundStyle(.black)
        .accessibilityIdentifier("book-next-step")
    }

    /// Where a book read stands, in the place of the next step: "✓ Lu", which
    /// opens the full choice of status, as the "…" menu does, for a book read
    /// again or given up after all.
    private var readButton: some View {
        Menu {
            Picker(selection: Binding(get: { book.status }, set: onSetStatus)) {
                ForEach(ReadingStatus.progression) { status in
                    Text(status.label).tag(status)
                }
            } label: {
                Text("Statut")
            }
            .pickerStyle(.inline)
        } label: {
            HeroButtonLabel(title: "Lu", systemImage: "checkmark")
        }
        .menuStyle(.button)
        .buttonStyle(.glassProminent)
        .tint(.white)
        .foregroundStyle(.black)
        .accessibilityIdentifier("book-read-status")
    }

    /// The stars once given, else the way to give them. The saga's stars lent
    /// to a volume are not drawn here: grey on glass they read as five empty
    /// stars, and the button's work is to rate this book.
    private func ratingButton(prominent: Bool) -> some View {
        let label = Group {
            if let rating = book.rating {
                // In the button's own colour, as the heart beside the
                // title bar is: the hero keeps to white on glass.
                RatingStars(rating: rating, font: .footnote, monochrome: true)
                    .frame(height: HeroButtonLabel.height)
            } else {
                HeroButtonLabel(title: "Noter", systemImage: "star")
            }
        }
        return Group {
            if prominent {
                Button(action: onRate) { label }
                    .buttonStyle(.glassProminent)
                    .tint(.white)
                    .foregroundStyle(.black)
            } else {
                Button(action: onRate) { label }
                    .buttonStyle(.glass)
            }
        }
        .accessibilityIdentifier(book.rating != nil ? "book-rating" : "book-rate")
    }

    /// The reader's remarks on the book, whatever its status: what they
    /// thought of it so far, or once read. Once written, the button takes the
    /// reader to them; their bubble opens the form.
    private var noteButton: some View {
        Button {
            if book.note == nil { onEditNote() } else { noteRequest += 1 }
        } label: {
            HeroButtonLabel(title: "Remarques", systemImage: "text.bubble")
        }
        .buttonStyle(.glass)
        .accessibilityIdentifier("book-hero-note")
    }

    // MARK: - Blocks

    @ViewBuilder private var synopsis: some View {
        if let synopsis = book.synopsis {
            BookSynopsisBlock(synopsis: synopsis)
        }
    }

    private var facts: some View {
        VStack(alignment: .leading, spacing: 12) {
            RowHeader(title: "Informations", detail: String(localized: "modifier"), action: onEdit)
                .accessibilityIdentifier("book-edit-facts")
            // When the reader added, started and finished it, over what the
            // book is: one table, the reading's days three to a row.
            FactGrid(
                groups: [
                    FactGroup(tiles: dayTiles, columns: 3),
                    FactGroup(tiles: factTiles),
                ],
                links: storeLinks
            )
        }
    }

    private var factTiles: [FactTile] {
        var tiles = [
            FactTile(
                id: "genre",
                title: "Genre",
                value: book.genre?.label,
                chips: book.subgenres,
                isWide: true,
                showsChevron: true,
                action: onEditGenre
            ),
            FactTile(id: "format", title: "Format", value: formatValue, action: onEdit),
            FactTile(id: "publisher", title: "Éditeur", value: book.publisher, action: onEdit),
            FactTile(
                id: "firstPublishedIn",
                title: "Parution",
                value: book.firstPublishedIn.map(String.init),
                action: { onEditField(.firstPublishedIn) }
            ),
        ]
        if let duration = book.durationLabel {
            tiles.append(FactTile(id: "duration", title: "Durée", value: duration))
        } else {
            tiles.append(FactTile(
                id: "pageCount",
                title: "Pages",
                value: book.pageCount.map(String.init),
                action: { onEditField(.pageCount) }
            ))
        }
        if BookFact.editionYear.applies(to: book), let year = book.editionYear {
            tiles.append(FactTile(id: "editionYear", title: "Année d'édition", value: String(year), action: onEdit))
        }
        if book.format != .audiobook {
            tiles.append(FactTile(
                id: "isbn13",
                title: "ISBN",
                value: book.isbn13,
                valueFont: .subheadline.weight(.semibold).monospacedDigit(),
                action: { onEditField(.isbn13) }
            ))
        }
        return tiles
    }

    /// What the book is and how the reader holds it, in one tile: "Livre ·
    /// papier", "Manga · papier et numérique", "Livre audio".
    private var formatValue: String {
        guard book.format != .audiobook, !book.media.isEmpty else { return book.format.label }
        return "\(book.format.label) · \(BookMedium.label(of: book.media).lowercased())"
    }

    /// Ways out of Shiori, closing the facts they complete.
    private var storeLinks: [FactLink] {
        [
            book.audibleURL.map { FactLink(id: "audible", title: "Écouter sur Audible", logo: "audible-logo", url: $0) },
            book.amazonURL.map { FactLink(id: "amazon", title: "Voir sur Amazon", logo: "amazon-logo", url: $0) },
        ].compactMap { $0 }
    }

    /// The editions of it the reader awaits, as the saga screen lists them.
    @ViewBuilder private var awaitedBlock: some View {
        let found = awaited.filter { $0.state != .unannounced }
        if !found.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                RowHeader(title: "Éditions guettées")
                VStack(spacing: 0) {
                    ForEach(found) { edition in
                        Button { onOpenAwaited(edition) } label: {
                            AwaitedEditionReleaseRow(edition: edition)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Ne plus suivre", systemImage: "bell.slash", role: .destructive) {
                                onStopAwaiting(edition)
                            }
                        }
                        .accessibilityIdentifier("book-awaited-\(edition.format.rawValue)")
                        if edition.id != found.last?.id { Divider().padding(.leading, 14) }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
            }
        }
    }

    /// The saga under its own name, as the TV app heads a season, and the
    /// volumes the reader holds as covers — this one alone until the others
    /// arrive, or when it is the only one held.
    @ViewBuilder private var series: some View {
        if let membership = book.series {
            SeriesVolumesRow(
                name: membership.name,
                volumes: seriesVolumes.isEmpty ? [book] : seriesVolumes,
                currentId: book.id,
                onOpenSeries: onOpenSeries,
                onOpenVolume: onOpenVolume
            )
        }
    }

    // MARK: - Reading

    /// What was said of the book, as a conversation: the recommender's words
    /// in a grey bubble under their name, the reader's own answer in a blue
    /// one, as Messages draws a group. Nothing when nobody said anything: the
    /// remarks are written from the hero.
    @ViewBuilder private var reading: some View {
        if book.recommendation != nil || book.note != nil {
            VStack(alignment: .leading, spacing: 12) {
                RowHeader(title: "Commentaires", detail: readingSpan)
                VStack(spacing: 10) {
                    // A recommendation that names someone and says nothing
                    // still reads as their word on it.
                    if let recommendation = book.recommendation {
                        MessageBubble(
                            text: recommendation.comment ?? String(localized: "Je te le conseille."),
                            sender: recommendation.recommenderName ?? String(localized: "Conseillé"),
                            action: onEditRecommendation
                        )
                        .accessibilityIdentifier("book-recommendation-comment")
                    }
                    if let note = book.note {
                        MessageBubble(text: note, isMine: true, action: onEditNote)
                            .copyable(note)
                            .id(Self.noteAnchor)
                            .accessibilityIdentifier("book-note")
                    }
                }
            }
        }
    }

    /// How long the book took, once read.
    private var readingSpan: String? {
        guard book.status == .read, let started = book.startedAt, let finished = book.finishedAt else { return nil }
        let days = max(1, started.daysAgo(from: finished))
        return days == 1 ? String(localized: "lu en un jour") : String(localized: "lu en \(days) jours")
    }

    private var dayTiles: [FactTile] {
        let day: (Date?) -> String? = { $0?.formatted(.dateTime.day().month(.abbreviated)) }
        // A day not reached yet reads as a dash and opens nothing.
        let edit: (BookField) -> (() -> Void)? = { field in
            field.isEditable(on: book) ? { onEditField(field) } : nil
        }
        return [
            FactTile(id: "addedAt", title: "Ajouté", value: day(book.addedAt), placeholder: "—", action: edit(.addedAt)),
            FactTile(id: "startedAt", title: "Commencé", value: day(book.startedAt), placeholder: "—", action: edit(.startedAt)),
            FactTile(id: "finishedAt", title: "Terminé", value: day(book.finishedAt), placeholder: "—", action: edit(.finishedAt)),
        ]
    }
}

/// The step a book waits for, which the hero's first button takes. None for a
/// book read: moving it back to reading clears the day it was finished.
struct NextStep: Equatable {
    let title: LocalizedStringKey
    let systemImage: String
    let status: ReadingStatus

    init?(status: ReadingStatus) {
        switch status {
        case .toRead:
            (title, systemImage, self.status) = ("Commencer", "book.fill", .reading)
        case .reading:
            (title, systemImage, self.status) = ("Marquer lu", "checkmark", .read)
        case .read:
            return nil
        case .dropped:
            (title, systemImage, self.status) = ("Reprendre", "arrow.uturn.backward", .reading)
        }
    }
}

/// A hero button's label: the symbol in the text's own font, so a checkmark,
/// a star and a bubble stand at one size and weight beside their words, six
/// points from them — `Label` in a glass button leaves a wider gap than
/// Apple's own buttons do — and one height whatever the symbol.
private struct HeroButtonLabel: View {
    let title: LocalizedStringKey
    let systemImage: String

    /// The label's height, which the stars match: a little taller than the
    /// regular glass button's own.
    static let height: CGFloat = 24

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .imageScale(.medium)
                .accessibilityHidden(true)
            Text(title)
        }
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 2)
        .frame(height: Self.height)
    }
}

extension Book {
    /// A book read halfway, with every section of its page filled in.
    static let preview = Book(
        id: "1",
        title: "Le Nom du vent",
        authors: ["Patrick Rothfuss"],
        format: .audiobook,
        publisher: "Bragelonne",
        firstPublishedIn: 2007,
        editionYear: 2015,
        synopsis: "Kvothe raconte sa propre légende : l'enfance sur les routes, la misère à Tarbean, l'Université et la magie qu'on y apprend.",
        genre: .fantasy,
        subgenres: ["Roman initiatique", "Aventure"],
        pageCount: 662,
        audibleURL: URL(string: "https://www.audible.fr/pd/B00X57B4KE"),
        amazonURL: URL(string: "https://www.amazon.fr/s?k=Le+Nom+du+vent+Patrick+Rothfuss&i=audible&tag=polyforms-21"),
        isbn13: "9782352943556",
        series: SeriesMembership(id: "s1", name: "Chronique du tueur de roi", volume: 1, kind: .main),
        status: .reading,
        note: "La scène de l'auberge, au début, vaut le livre entier.",
        recommendation: BookRecommendation(recommenderName: "Marie Curie", comment: "Lis-le cet été."),
        hidden: true,
        addedAt: .now.addingTimeInterval(-86400 * 32),
        startedAt: .now.addingTimeInterval(-86400 * 20)
    )
}

extension Book {
    /// A manga volume just added from a shelf photo: what its spine printed,
    /// a cover found by title, nothing described yet.
    static let previewFromShelf = Book(
        id: "2",
        title: "One Piece",
        authors: ["Eiichiro Oda"],
        format: .manga,
        language: .fr,
        series: SeriesMembership(id: "s2", name: "One Piece", volume: 5, kind: .main),
        coverURL: URL(string: "https://m.media-amazon.com/images/P/2723434826.01._SCLZZZZZZZ_.jpg"),
        status: .toRead,
        awaitingDescription: true
    )
}

private extension BookPage {
    init(previewing book: Book, volumes: [Book] = []) {
        self.init(
            book: book,
            isSaving: false,
            onSetStatus: { _ in },
            onRate: {},
            onOpenSeries: {},
            onEdit: {},
            onEditGenre: {},
            onEditRecommendation: {},
            onEditNote: {},
            onEditField: { _ in },
            seriesVolumes: volumes
        )
    }
}

#Preview("Reading") {
    NavigationStack {
        BookPage(previewing: .preview)
    }
}

#Preview("From a shelf") {
    NavigationStack {
        BookPage(previewing: .previewFromShelf)
    }
}

#Preview("Unfolded", traits: .fixedLayout(width: 951, height: 669)) {
    NavigationStack {
        BookPage(previewing: .preview)
    }
}
