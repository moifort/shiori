import SwiftUI

/// One book's screen. Pure and previewable: the cover and the facts, then what
/// the reader thinks of it, then the rest of its saga.
///
/// The order is deliberate. Judgment sits above the synopsis because a reader
/// opening a book they have read came to rate or annotate it, not to re-read
/// the blurb.
///
/// Removing the book is not here: it lives in the sheet's toolbar menu, where a
/// destructive action is one deliberate step away rather than at the foot of a
/// scroll.
struct BookPage: View {
    let book: Book
    let otherVolumes: [Volume]
    let seriesName: String?
    let isSaving: Bool
    let onSetStatus: (ReadingStatus) -> Void
    let onSetFormat: (BookFormat) -> Void
    let onRate: (Int) -> Void
    let onEditNote: () -> Void
    let onToggleHidden: () -> Void
    let onOpenSeries: () -> Void
    let onAddVolume: (Volume) -> Void

    private var currentYear: Int { Calendar.current.component(.year, from: .now) }

    var body: some View {
        List {
            header
            statusSection
            ratingSection
            noteSection
            if !otherVolumes.isEmpty { recommendationsSection }
            detailsSection
            sharingSection
        }
        .listStyle(.insetGrouped)
        .disabled(isSaving)
    }

    private var header: some View {
        Section {
            HStack(alignment: .top, spacing: 16) {
                BookCover(book: book, width: 96)
                VStack(alignment: .leading, spacing: 6) {
                    Text(book.title).font(.title3.bold())
                    Text(book.authorLine).font(.subheadline).foregroundStyle(.secondary)
                    if let series = book.series {
                        Button(action: onOpenSeries) {
                            Label("\(series.name) · \(series.label)", systemImage: "square.stack")
                                .font(.footnote)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.tint)
                        .padding(.top, 2)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
        }
    }

    private var statusSection: some View {
        Section("Lecture") {
            Picker("Statut", selection: statusBinding) {
                ForEach(ReadingStatus.allCases) { status in
                    Text(status.label).tag(status)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("book-status")

            if let started = book.startedAt {
                LabeledContent("Commencé le", value: started.formatted(date: .abbreviated, time: .omitted))
            }
            if let finished = book.finishedAt {
                LabeledContent("Terminé le", value: finished.formatted(date: .abbreviated, time: .omitted))
            }
        }
    }

    private var statusBinding: Binding<ReadingStatus> {
        Binding(get: { book.status }, set: onSetStatus)
    }

    private var ratingSection: some View {
        Section("Note") {
            // allowsUnset is off on purpose: the component's own note says the
            // API merges what it receives and cannot express "erase this one",
            // so tapping the current star to clear would silently do nothing.
            InteractiveStarRating(
                rating: Binding(
                    get: { book.rating ?? 0 },
                    set: { stars in if stars > 0 { onRate(stars) } }
                ),
                allowsUnset: false
            )
            .accessibilityIdentifier("book-rating")
            if book.rating == nil {
                Text("Noter un livre le marque comme lu.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var noteSection: some View {
        Section("Mon commentaire") {
            Button(action: onEditNote) {
                if let note = book.note, !note.isEmpty {
                    Text(note).font(.body).foregroundStyle(.primary)
                } else {
                    Label("Écrire un commentaire", systemImage: "square.and.pencil")
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("book-note")
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

    private var detailsSection: some View {
        Section("Informations") {
            if let synopsis = book.synopsis {
                Text(synopsis).font(.callout)
            }
            // Editable because the scan guesses it from the cover, and a guess can
            // take a graphic novel for a comic.
            Picker("Format", selection: Binding(get: { book.format }, set: onSetFormat)) {
                ForEach(BookFormat.allCases) { Text($0.label).tag($0) }
            }
            .accessibilityIdentifier("book-format")
            if let publisher = book.publisher {
                LabeledContent("Éditeur", value: publisher)
            }
            if let year = book.firstPublishedIn {
                LabeledContent("Première parution", value: String(year))
            }
            if let pages = book.pageCount {
                LabeledContent("Pages", value: String(pages))
            }
            if !book.genres.isEmpty {
                LabeledContent("Genres", value: book.genres.joined(separator: ", "))
            }
            if let isbn = book.isbn13 {
                LabeledContent("ISBN", value: isbn).font(.caption.monospaced())
            }
        }
    }

    private var sharingSection: some View {
        Section {
            Toggle(isOn: Binding(get: { book.hidden }, set: { _ in onToggleHidden() })) {
                Label("Ne pas partager", systemImage: "eye.slash")
            }
            .accessibilityIdentifier("book-hidden")
        } footer: {
            Text("Un livre masqué n'apparaîtra jamais dans une bibliothèque partagée.")
        }
    }}

#Preview {
    NavigationStack {
        BookPage(
            book: Book(
                id: "1",
                title: "Le Nom du vent",
                authors: ["Patrick Rothfuss"],
                publisher: "Bragelonne",
                firstPublishedIn: 2007,
                synopsis: "Kvothe raconte sa propre légende : l'enfance sur les routes, la misère à Tarbean, l'Université et la magie qu'on y apprend.",
                genres: ["Fantasy"],
                pageCount: 662,
                isbn13: "9782352943556",
                series: SeriesMembership(id: "s1", name: "Chronique du tueur de roi", volume: 1, kind: .main),
                status: .read,
                rating: 5,
                note: "La meilleure prose de fantasy que j'aie lue.",
                startedAt: .now.addingTimeInterval(-86400 * 20),
                finishedAt: .now
            ),
            otherVolumes: [
                Volume(number: 2, title: "La Peur du sage", publishedIn: 2011, kind: .main),
                Volume(number: 3, title: "Les Portes de pierre", publishedIn: nil, kind: .main),
                Volume(number: nil, title: "La Musique du silence", publishedIn: 2014, kind: .novella),
            ],
            seriesName: "Chronique du tueur de roi",
            isSaving: false,
            onSetStatus: { _ in },
            onSetFormat: { _ in },
            onRate: { _ in },
            onEditNote: {},
            onToggleHidden: {},
            onOpenSeries: {},
            onAddVolume: { _ in }
        )
    }
}
