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
    /// draws no row: a book on its own, or volumes not read yet.
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
        ScrollView {
            VStack(spacing: 0) { content() }
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
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    if let step = NextStep(status: book.status) {
                        primaryButton(step)
                        ratingButton(prominent: false)
                    } else {
                        // A book read waits for the reader's word on it, not
                        // for a next state: reading it again clears the day it
                        // was finished, a choice made in the menu, not here.
                        ratingButton(prominent: book.rating == nil)
                        noteButton
                    }
                }
            }
        }
        .sensoryFeedback(.success, trigger: book.status)
    }

    /// The next step the book is waiting for.
    private func primaryButton(_ step: NextStep) -> some View {
        Button {
            onSetStatus(step.status)
        } label: {
            Label(step.title, systemImage: step.systemImage)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 4)
        }
        .buttonStyle(.glassProminent)
        .tint(.white)
        .foregroundStyle(.black)
        .controlSize(.large)
        .accessibilityIdentifier("book-next-step")
    }

    /// The stars once given, else the way to give them. The saga's stars lent
    /// to a volume are not drawn here: grey on glass they read as five empty
    /// stars, and the button's work is to rate this book.
    private func ratingButton(prominent: Bool) -> some View {
        let label = Group {
            if let rating = book.rating {
                RatingStars(rating: rating, font: .footnote)
                    .padding(.vertical, 2)
            } else {
                Label("Noter", systemImage: "star")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .padding(.horizontal, 4)
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
        .controlSize(.large)
        .accessibilityIdentifier(book.rating != nil ? "book-rating" : "book-rate")
    }

    /// The reader's comment on a book read, from the hero.
    private var noteButton: some View {
        Button(action: onEditNote) {
            Label(book.note == nil ? "Commenter" : "Commentaire", systemImage: "text.bubble")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 4)
        }
        .buttonStyle(.glass)
        .controlSize(.large)
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
            RowHeader(title: "Informations", detail: String(localized: "Modifier"), action: onEdit)
                .accessibilityIdentifier("book-edit-facts")
            FactGrid(tiles: factTiles)
            storeLinks
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

    /// Ways out of Shiori, under the facts they complete.
    @ViewBuilder private var storeLinks: some View {
        let links = [
            book.audibleURL.map { ("Audible", $0, Color.audible as Color?) },
            book.amazonURL.map { ("Amazon", $0, nil as Color?) },
        ].compactMap { $0 }
        if !links.isEmpty {
            HStack(spacing: 8) {
                ForEach(links, id: \.0) { name, url, tint in
                    Link(destination: url) {
                        Pill(text: name, tint: tint, trailingSystemImage: "arrow.up.right")
                    }
                    .accessibilityLabel(Text("Ouvrir dans \(name)"))
                    .accessibilityIdentifier("book-store-link-\(name.lowercased())")
                }
            }
        }
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

    @ViewBuilder private var series: some View {
        if let membership = book.series, seriesVolumes.count > 1 {
            SeriesVolumesRow(
                name: membership.name,
                volumes: seriesVolumes,
                currentId: book.id,
                onOpenSeries: onOpenSeries,
                onOpenVolume: onOpenVolume
            )
        } else if let membership = book.series {
            // Alone on the shelf, the saga is a link rather than a row of one.
            VStack(alignment: .leading, spacing: 12) {
                RowHeader(title: "Série", detail: membership.name, action: onOpenSeries)
                    .accessibilityIdentifier("book-series")
            }
        }
    }

    // MARK: - Reading

    private var reading: some View {
        VStack(alignment: .leading, spacing: 12) {
            RowHeader(title: "Ma lecture", detail: readingSpan)
            FactGrid(tiles: dayTiles, columns: 3)
            if let recommendation = book.recommendation {
                recommendationRow(recommendation)
            }
            note
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
        return [
            FactTile(id: "addedAt", title: "Ajouté", value: day(book.addedAt), placeholder: "—", action: { onEditField(.addedAt) }),
            FactTile(id: "startedAt", title: "Commencé", value: day(book.startedAt), placeholder: "—", action: { onEditField(.startedAt) }),
            FactTile(id: "finishedAt", title: "Terminé", value: day(book.finishedAt), placeholder: "—", action: { onEditField(.finishedAt) }),
        ]
    }

    /// Who pressed the book on the reader, and what they said of it.
    private func recommendationRow(_ recommendation: BookRecommendation) -> some View {
        Button(action: onEditRecommendation) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    if let name = recommendation.recommenderName {
                        Text("Conseillé par \(name)").font(.subheadline.weight(.semibold))
                    } else {
                        Text("Livre conseillé").font(.subheadline.weight(.semibold))
                    }
                    if let comment = recommendation.comment {
                        Text(comment).font(.callout).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("book-recommendation")
    }

    /// The reader's own comment, read as a review: the text, then when and a
    /// way to correct it. Without one, the button that writes it.
    @ViewBuilder private var note: some View {
        if let note = book.note {
            Button(action: onEditNote) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(note)
                        .font(.body)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Modifier le commentaire")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 6)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .copyable(note)
            .accessibilityIdentifier("book-note")
        } else {
            Button(action: onEditNote) {
                Label("Ajouter un commentaire", systemImage: "text.bubble")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(.primary)
            .padding(.top, 4)
            .accessibilityIdentifier("book-note")
        }
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
            (title, systemImage, self.status) = ("Commencer la lecture", "book.fill", .reading)
        case .reading:
            (title, systemImage, self.status) = ("Marquer lu", "checkmark", .read)
        case .read:
            return nil
        case .dropped:
            (title, systemImage, self.status) = ("Reprendre", "arrow.uturn.backward", .reading)
        }
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
