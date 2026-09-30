import SwiftUI

/// One book's screen, laid out like Vinarium's wine sheet: the status first, then
/// what the book is, then the reader's own reading, then the summary. Pure and
/// previewable.
///
/// The status and sharing are switched in place, and the publisher, the
/// year, the pages and the ISBN are typed straight into their row; a tap on
/// the rating or a date opens a small prompt to correct that one value, as
/// the genre and the recommendation open theirs. The title, the
/// authors and the saga go through "Modifier" in the sheet's menu, which is
/// also where removing the book lives, one deliberate step away.
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
    let onEditRecommendation: () -> Void
    let onEditNote: () -> Void
    let onEditField: (BookField) -> Void
    /// A fact typed in place on its row: the publisher, the year, the pages,
    /// the ISBN.
    let onCorrect: (BookCorrection) -> Void
    /// The editions of this book the reader awaits in the app's language.
    var awaited: [AwaitedEdition] = []
    var onStopAwaiting: (AwaitedEdition) -> Void = { _ in }

    var body: some View {
        List {
            BookStatusSection(status: book.status, onSetStatus: onSetStatus)
            BookHeaderSection(
                book: book,
                isAwaited: !awaited.isEmpty,
                actions: .init(
                    openSeries: onOpenSeries,
                    editGenre: onEditGenre,
                    correct: onCorrect
                )
            )
            AwaitedEditionsSection(awaited: awaited, onStop: onStopAwaiting)
            BookReadingSection(
                title: "Ma lecture",
                book: book,
                onRate: onRate,
                onEditField: onEditField,
                footer: "Un livre non partagé n'apparaîtra jamais dans une bibliothèque partagée."
            ) {
                if let recommendation = book.recommendation {
                    recommendationRows(recommendation)
                }
                noteRow
                Toggle(isOn: Binding(get: { book.hidden }, set: { _ in onToggleHidden() })) {
                    Label {
                        Text("Ne pas partager")
                    } icon: {
                        Image(systemName: "eye.slash").foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("book-hidden")
            }
            if let synopsis = book.synopsis { BookSynopsisSection(synopsis: synopsis) }
        }
        .listStyle(.insetGrouped)
        .labelStyle(.row)
        .disabled(isSaving)
    }

    /// The reader's own comment, whole, under the reading it is about. A tap
    /// corrects it; without one, the row offers to write it.
    private var noteRow: some View {
        Button(action: onEditNote) {
            if let note = book.note {
                Label {
                    Text(note).font(.callout)
                } icon: {
                    Image(systemName: "text.bubble").foregroundStyle(.secondary)
                }
            } else {
                Label("Ajouter un commentaire", systemImage: "text.bubble")
            }
        }
        .tint(book.note == nil ? nil : .primary)
        .copyable(book.note ?? "")
        .accessibilityIdentifier("book-note")
    }

    /// Who pressed the book on the reader, as in Vinarium's wine sheet. Only
    /// drawn once there is one: the menu's "Conseillé par…" is how a
    /// reader adds it, and a tap here corrects it. Part of the reading rather
    /// than a section of its own: one row did not earn a heading.
    @ViewBuilder
    private func recommendationRows(_ recommendation: BookRecommendation) -> some View {
        Button(action: onEditRecommendation) {
            Label {
                if let name = recommendation.recommenderName {
                    LabeledContent("Conseillé par") {
                        Text(name).foregroundStyle(.tint)
                    }
                } else {
                    Text("Livre conseillé")
                }
            } icon: {
                Image(systemName: "person.badge.plus").foregroundStyle(.secondary)
            }
        }
        .tint(.primary)
        .accessibilityIdentifier("book-recommendation")

        if let comment = recommendation.comment {
            Label {
                Text(comment).font(.callout)
            } icon: {
                Image(systemName: "text.quote").foregroundStyle(.secondary)
            }
            .copyable(comment)
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
                audibleURL: URL(string: "https://www.audible.fr/pd/B00X57B4KE"),
                isbn13: "9782352943556",
                series: SeriesMembership(id: "s1", name: "Chronique du tueur de roi", volume: 1, kind: .main),
                status: .reading,
                note: "La scène de l'auberge, au début, vaut le livre entier.",
                recommendation: BookRecommendation(recommenderName: "Marie Curie", comment: "Lis-le cet été."),
                hidden: true,
                startedAt: .now.addingTimeInterval(-86400 * 20)
            ),
            isSaving: false,
            onSetStatus: { _ in },
            onRate: {},
            onToggleHidden: {},
            onOpenSeries: {},
            onEditGenre: {},
            onEditRecommendation: {},
            onEditNote: {},
            onEditField: { _ in },
            onCorrect: { _ in }
        )
    }
}
