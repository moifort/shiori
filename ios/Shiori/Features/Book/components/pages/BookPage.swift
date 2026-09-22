import SwiftUI

/// One book's screen, laid out like Vinarium's wine sheet: the status first, then
/// what the book is, then the reader's own reading, then the summary. Pure and
/// previewable.
///
/// The page reads rather than edits. Only the things a reader flips often —
/// the status, sharing, and the genre from its own row — are changed in place,
/// and a missing rating gets a call to action. Every other correction goes
/// through "Modifier" in the sheet's menu, which is also where removing the
/// book lives, one deliberate step away.
///
/// The other volumes of the saga are not listed here: that list belongs to the
/// series screen, one tap away on the series row, which is the one place that
/// knows the whole catalogue.
struct BookPage: View {
    let book: Book
    let isSaving: Bool
    let onSetStatus: (ReadingStatus) -> Void
    let onRate: () -> Void
    let onToggleHidden: () -> Void
    let onOpenSeries: () -> Void
    let onEditGenre: () -> Void

    /// Past this many words the summary folds, and a button unfolds it: an
    /// Audible blurb can run to a screenful, and the facts below it were
    /// scrolling out of reach.
    static let summaryWordLimit = 500

    @State private var summaryExpanded = false

    var body: some View {
        List {
            statusSection
            header
            readingSection
            if let synopsis = book.synopsis { synopsisSection(synopsis) }
        }
        .listStyle(.insetGrouped)
        .labelStyle(.row)
        .disabled(isSaving)
    }

    /// Sits straight on the sheet rather than in a card: it is the control the
    /// reader comes back for, not one row among the book's facts.
    private var statusSection: some View {
        Section {
            ReadingStatusPicker(status: Binding(get: { book.status }, set: onSetStatus))
                .accessibilityIdentifier("book-status")
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
        }
    }

    /// What the book is: the cover and the title, its place in a saga, and the
    /// facts of its publication, in one section rather than two — a reader
    /// looking for the publisher was scrolling past a heading to find it.
    private var header: some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                BookCover(book: book, width: 64)
                VStack(alignment: .leading, spacing: 2) {
                    // The volume before the title, beside the cover, as the
                    // library row says it: "Tome 3" is how a reader names a
                    // book of a saga before its title.
                    if let series = book.series {
                        Text(series.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text(book.title).font(.headline)
                    Text(book.authorLine).font(.subheadline).foregroundStyle(.secondary)
                    // Who reads a recording is as much a reason to pick it as
                    // who wrote it, so it sits with the author rather than down
                    // among the details. Only a recording has a reader.
                    if let narratorLine = book.narratorLine {
                        Text("Lu par \(narratorLine)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 1)
                    }
                }
                Spacer(minLength: 8)
                // How long a recording runs, as a pill in the corner: the one
                // number a listener weighs before starting. That it is a
                // recording is said by the pill on the cover; a drawn story
                // keeps its format glyph here, a prose book needs none.
                // A dropped book says so here too: the picker above has no
                // segment for it.
                HStack(spacing: 6) {
                    if book.status == .dropped {
                        ReadingStatusBadge(status: .dropped)
                            .scaleEffect(1.2)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text(book.status.label))
                            .accessibilityIdentifier("book-dropped")
                    }
                    // How far the Audible player got, while the recording is
                    // under way only: before, there is nothing to tell, and
                    // once it is over the status says it.
                    if book.status == .reading, let progress = book.listeningProgressLabel {
                        // In the colour of "En cours", which it measures.
                        Pill(text: progress, tint: ReadingStatus.reading.tint)
                            .accessibilityLabel(Text("Écouté à \(progress)"))
                            .accessibilityIdentifier("book-listening-progress")
                    }
                    if let durationLabel = book.durationLabel {
                        Pill(text: durationLabel, systemImage: "clock")
                            .accessibilityIdentifier("book-duration")
                    }
                    if book.format != .book && book.format != .audiobook {
                        Image(systemName: book.format.symbol)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(Text(book.format.label))
                            .accessibilityIdentifier("book-format")
                    }
                }
            }
            .padding(.vertical, 2)
            .copyable([
                CopyableValue(title: "Copier le titre", value: book.title),
                CopyableValue(title: "Copier l'auteur", value: book.authors.joined(separator: ", ")),
                CopyableValue(title: "Copier le lecteur", value: book.narratorLine ?? ""),
            ])

            if let series = book.series {
                Button(action: onOpenSeries) {
                    Label {
                        LabeledContent("Série") {
                            HStack(spacing: 4) {
                                Text(series.name).multilineTextAlignment(.trailing)
                                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(.tint)
                        }
                    } icon: {
                        Image(systemName: "square.stack").foregroundStyle(.secondary)
                    }
                }
                .tint(.primary)
                .accessibilityIdentifier("book-series")
            }

            genreRow

            if let publisher = book.publisher {
                LabeledInfoRow(title: "Éditeur", value: publisher, icon: "building.2")
            }
            if let year = book.firstPublishedIn {
                LabeledInfoRow(title: "Première parution", value: String(year), icon: "calendar")
            }
            if let pages = book.pageCount {
                LabeledInfoRow(title: "Pages", value: String(pages), icon: "doc.plaintext")
            }
            if let isbn = book.isbn13 {
                Label {
                    LabeledContent("ISBN") {
                        Text(isbn).font(.callout.monospaced())
                    }
                } icon: {
                    Image(systemName: "barcode").foregroundStyle(.secondary)
                }
                .copyable(isbn)
            }
        }
    }

    /// The genre and its subgenres on one tappable row. A book with neither
    /// still gets the row, saying so: it is the way to give it one.
    private var genreRow: some View {
        Button(action: onEditGenre) {
            Label {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Genre") {
                        HStack(spacing: 4) {
                            if let genre = book.genre {
                                genre.image.imageScale(.small)
                            }
                            Text(book.genre?.label ?? String(localized: "Non renseigné"))
                                .multilineTextAlignment(.trailing)
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.tint)
                    }
                    if !book.subgenres.isEmpty {
                        TagList(tags: book.subgenres, systemImage: "tag")
                    }
                }
            } icon: {
                // Neutral here: the genre's own glyph sits beside its name.
                Image(systemName: "books.vertical").foregroundStyle(.secondary)
            }
        }
        .tint(.primary)
        .accessibilityIdentifier("book-genre")
    }

    private var readingSection: some View {
        Section {
            if let rating = book.rating {
                Label {
                    LabeledContent("Note") { StarRatingView(rating: rating) }
                } icon: {
                    Image(systemName: "star").foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("book-rating")
            } else if let seriesRating = book.seriesRating {
                // The saga's stars, lent to this volume: grey, named as such,
                // and a tap gives the book a rating of its own.
                Button(action: onRate) {
                    Label {
                        LabeledContent {
                            StarRatingView(rating: seriesRating, inherited: true)
                        } label: {
                            Text("Note")
                            Text("Héritée de la série")
                        }
                    } icon: {
                        Image(systemName: "star").foregroundStyle(.secondary)
                    }
                }
                .tint(.primary)
                .accessibilityIdentifier("book-rating-inherited")
            } else {
                Button(action: onRate) {
                    Label("Noter ce livre", systemImage: "star")
                }
                .accessibilityIdentifier("book-rate")
            }

            if let added = book.addedAt {
                LabeledInfoRow(
                    title: "Ajouté le",
                    value: added.formatted(date: .abbreviated, time: .omitted),
                    icon: "tray.and.arrow.down"
                )
            }
            if let started = book.startedAt {
                LabeledInfoRow(
                    title: "Commencé le",
                    value: started.formatted(date: .abbreviated, time: .omitted),
                    icon: "calendar.badge.plus"
                )
            }
            if let finished = book.finishedAt {
                LabeledInfoRow(
                    title: "Terminé le",
                    value: finished.formatted(date: .abbreviated, time: .omitted),
                    icon: "calendar.badge.checkmark"
                )
            }

            Toggle(isOn: Binding(get: { book.hidden }, set: { _ in onToggleHidden() })) {
                Label {
                    Text("Ne pas partager")
                } icon: {
                    Image(systemName: "eye.slash").foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("book-hidden")
        } header: {
            Text("Ma lecture")
        } footer: {
            Text("Un livre non partagé n'apparaîtra jamais dans une bibliothèque partagée.")
        }
    }

    private func synopsisSection(_ synopsis: String) -> some View {
        let words = synopsis.split(whereSeparator: \.isWhitespace)
        let folded = words.count > Self.summaryWordLimit && !summaryExpanded
        let shown = folded ? words.prefix(Self.summaryWordLimit).joined(separator: " ") + "…" : synopsis
        return Section("Résumé") {
            // The whole summary, folded or not: what is copied is the text,
            // not the part of it on screen.
            Text(shown).font(.callout).copyable(synopsis)
            if words.count > Self.summaryWordLimit {
                Button(folded ? "Lire la suite" : "Réduire") {
                    withAnimation(.snappy) { summaryExpanded.toggle() }
                }
                .font(.callout)
                .accessibilityIdentifier("book-summary-toggle")
            }
        }
    }
}

#Preview {
    NavigationStack {
        BookPage(
            book: Book(
                id: "1",
                title: "Le Nom du vent",
                authors: ["Patrick Rothfuss"],
                format: .audiobook,
                publisher: "Bragelonne",
                firstPublishedIn: 2007,
                synopsis: "Kvothe raconte sa propre légende : l'enfance sur les routes, la misère à Tarbean, l'Université et la magie qu'on y apprend.",
                genre: .fantasy,
                subgenres: ["Roman initiatique", "Aventure"],
                pageCount: 662,
                isbn13: "9782352943556",
                series: SeriesMembership(id: "s1", name: "Chronique du tueur de roi", volume: 1, kind: .main),
                status: .reading,
                hidden: true,
                startedAt: .now.addingTimeInterval(-86400 * 20)
            ),
            isSaving: false,
            onSetStatus: { _ in },
            onRate: {},
            onToggleHidden: {},
            onOpenSeries: {},
            onEditGenre: {}
        )
    }
}
