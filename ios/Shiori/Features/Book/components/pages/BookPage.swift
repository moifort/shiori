import SwiftUI

/// One book's screen, laid out like Vinarium's wine sheet: the status first, then
/// what the book is, then the reader's own reading, then the facts. Pure and
/// previewable.
///
/// The page reads rather than edits. Only the two things a reader flips often —
/// the status and sharing — are switched in place, and a missing rating gets a
/// call to action. Every other correction goes through "Modifier" in the sheet's
/// menu, which is also where removing the book lives, one deliberate step away.
struct BookPage: View {
    let book: Book
    let otherVolumes: [Volume]
    let seriesName: String?
    let isSaving: Bool
    let onSetStatus: (ReadingStatus) -> Void
    let onRate: () -> Void
    let onToggleHidden: () -> Void
    let onOpenSeries: () -> Void
    let onAddVolume: (Volume) -> Void

    private var currentYear: Int { Calendar.current.component(.year, from: .now) }

    var body: some View {
        List {
            statusSection
            header
            readingSection
            if let synopsis = book.synopsis { synopsisSection(synopsis) }
            publicationSection
            if !otherVolumes.isEmpty { recommendationsSection }
        }
        .listStyle(.insetGrouped)
        .disabled(isSaving)
    }

    private var statusSection: some View {
        Section {
            ReadingStatusPicker(status: Binding(get: { book.status }, set: onSetStatus))
                .accessibilityIdentifier("book-status")
        }
    }

    private var header: some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                BookCover(book: book, width: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title).font(.headline)
                    Text(book.authorLine).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)

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

                // Off the numbered spine there is no number, and the kind alone
                // ("Nouvelle") is what the volume is.
                LabeledInfoRow(title: "Tome", value: series.volume.map(String.init) ?? series.kind.label, icon: "number")
            }
            LabeledInfoRow(title: "Format", value: book.format.label, icon: book.format.symbol)
        }
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
            } else {
                Button(action: onRate) {
                    Label("Noter ce livre", systemImage: "star")
                }
                .accessibilityIdentifier("book-rate")
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
        Section("Résumé") {
            Text(synopsis).font(.callout)
        }
    }

    @ViewBuilder
    private var publicationSection: some View {
        let hasFacts = book.publisher != nil || book.firstPublishedIn != nil || book.pageCount != nil
            || !book.genres.isEmpty || book.isbn13 != nil
        if hasFacts {
            Section("Publication") {
                if let publisher = book.publisher {
                    LabeledInfoRow(title: "Éditeur", value: publisher, icon: "building.2")
                }
                if let year = book.firstPublishedIn {
                    LabeledInfoRow(title: "Première parution", value: String(year), icon: "calendar")
                }
                if let pages = book.pageCount {
                    LabeledInfoRow(title: "Pages", value: String(pages), icon: "doc.plaintext")
                }
                if !book.genres.isEmpty {
                    Label {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Genres")
                            TagList(tags: book.genres)
                        }
                    } icon: {
                        Image(systemName: "tag").foregroundStyle(.secondary)
                    }
                }
                if let isbn = book.isbn13 {
                    Label {
                        LabeledContent("ISBN") {
                            Text(isbn).font(.callout.monospaced())
                        }
                    } icon: {
                        Image(systemName: "barcode").foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    /// Zero-cost recommendation: the catalogue is already in hand, so the other
    /// volumes are a filter rather than a call. A volume the reader does not own
    /// is a proposal — nothing enters the library until they add it.
    private var recommendationsSection: some View {
        Section {
            ForEach(otherVolumes) { volume in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(volume.title).font(.subheadline.weight(.medium)).lineLimit(2)
                        HStack(spacing: 6) {
                            Text(volume.number.map { "\(volume.kind.label) \($0)" } ?? volume.kind.label)
                            if volume.isForthcoming(asOf: currentYear), let year = volume.publishedIn {
                                Text("· à paraître en \(String(year))")
                            } else if let year = volume.publishedIn {
                                Text("· \(String(year))")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Button {
                        onAddVolume(volume)
                    } label: {
                        Label("Ajouter", systemImage: "plus.circle")
                            .labelStyle(.iconOnly)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                    .accessibilityLabel(Text("Ajouter « \(volume.title) » à ma liste à lire"))
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("Dans la même série")
        } footer: {
            Text("Ajouter un tome depuis cette liste ne consomme aucun scan.")
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
                genres: ["Fantasy", "Roman initiatique", "Aventure"],
                pageCount: 662,
                isbn13: "9782352943556",
                series: SeriesMembership(id: "s1", name: "Chronique du tueur de roi", volume: 1, kind: .main),
                status: .reading,
                hidden: true,
                startedAt: .now.addingTimeInterval(-86400 * 20)
            ),
            otherVolumes: [
                Volume(number: 2, title: "La Peur du sage", publishedIn: 2011, kind: .main),
                Volume(number: 3, title: "Les Portes de pierre", publishedIn: nil, kind: .main),
            ],
            seriesName: "Chronique du tueur de roi",
            isSaving: false,
            onSetStatus: { _ in },
            onRate: {},
            onToggleHidden: {},
            onOpenSeries: {},
            onAddVolume: { _ in }
        )
    }
}
