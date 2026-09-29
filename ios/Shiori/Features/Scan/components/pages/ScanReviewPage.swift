import SwiftUI

/// What the model proposed, before anything is saved, drawn as the book's page
/// will draw it once saved: the status on top, the cover the scan found, the
/// title and the facts. Every fact is a guess — the safety net against a
/// misread cover — so every one can be corrected: the publisher, the year, the
/// pages and the ISBN typed in their row, every row shown even when the cover
/// said nothing; the head, the saga and the genre from a prompt. Moving the
/// book to "En cours" or "Lu" asks for the day. Nothing leaves the phone until
/// "Ajouter".
///
/// A saga renamed here is not the one the scan keyed: it is handed over by
/// name, and the server files the book as the edit form files one — into the
/// saga the reader holds by that name, or a new one keyed on its author.
struct ScanReviewPage: View {
    @State private var draft: BookDraft
    let isSaving: Bool
    /// The draft, and the saga as the reader renamed it, if they did.
    let onSave: (BookDraft, SeriesPlacement?) -> Void
    let onRetake: () -> Void

    @State private var editsIdentity = false
    @State private var editsSeries = false
    @State private var editsGenre = false
    @State private var renamedSeries: SeriesPlacement?
    @State private var askedDate: ReadingStatus?

    init(
        draft: BookDraft,
        isSaving: Bool,
        onSave: @escaping (BookDraft, SeriesPlacement?) -> Void,
        onRetake: @escaping () -> Void
    ) {
        _draft = State(initialValue: draft)
        self.isSaving = isSaving
        self.onSave = onSave
        self.onRetake = onRetake
    }

    private var book: Book {
        var book = draft.asReviewedBook
        if let renamedSeries {
            book.series = SeriesMembership(
                id: "",
                name: renamedSeries.name,
                volume: renamedSeries.volume,
                kind: .main
            )
        }
        return book
    }

    /// The finish that bounds the start: the one set on a read book, else today.
    private var latestStart: Date {
        draft.status == .read ? min(draft.finishedAt ?? .now, .now) : .now
    }

    /// The start as the server stamps it when left alone: the finish of a read
    /// book, else today.
    private var startedAt: Binding<Date> {
        Binding(
            get: { draft.startedAt.map { min($0, latestStart) } ?? latestStart },
            set: { draft.startedAt = $0 }
        )
    }

    private var finishedAt: Binding<Date> {
        Binding(get: { draft.finishedAt ?? .now }, set: { draft.finishedAt = $0 })
    }

    var body: some View {
        List {
            BookStatusSection(status: draft.status) { status in
                draft.status = status
                if status != .toRead { askedDate = status }
            }

            BookHeaderSection(
                book: book,
                actions: .init(
                    editSeries: { editsSeries = true },
                    editIdentity: { editsIdentity = true },
                    editGenre: { editsGenre = true },
                    correct: { draft.apply($0) }
                ),
                showsEmptyFacts: true,
                footer: "Lu automatiquement sur la couverture : touchez une ligne pour la corriger avant d'ajouter le livre."
            )

            // Where the book page keeps the reader's dates, and as it would
            // stamp them: only the ones the status carries.
            if draft.status != .toRead {
                BookReadingSection(title: "Ma lecture", book: book) {
                    readingDate(
                        "Commencé le",
                        icon: "calendar.badge.plus",
                        date: startedAt,
                        range: .distantPast...latestStart
                    )
                    .accessibilityIdentifier("review-started-at")
                    if draft.status == .read {
                        readingDate(
                            "Terminé le",
                            icon: "calendar.badge.checkmark",
                            date: finishedAt,
                            range: startedAt.wrappedValue...max(startedAt.wrappedValue, .now)
                        )
                        .accessibilityIdentifier("review-finished-at")
                    }
                }
            }

            if let synopsis = draft.synopsis {
                BookSynopsisSection(synopsis: synopsis)
            }
        }
        .listStyle(.insetGrouped)
        .labelStyle(.row)
        .navigationTitle("Vérifier")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .disabled(isSaving)
        .sheet(isPresented: $editsIdentity) {
            ScanIdentitySheet(book: book) { draft.apply($0) }
        }
        .sheet(isPresented: $editsGenre) {
            GenreEditSheet(book: book) { correction in
                draft.apply(correction)
                return nil
            }
        }
        .sheet(isPresented: $editsSeries) {
            SeriesJoinSheet(book: book) { correction in
                if case let .set(placement) = correction.series { renamedSeries = placement }
                return nil
            }
        }
        .sheet(item: $askedDate) { status in
            if status == .read {
                ReadingDateSheet(title: "Terminé le", date: finishedAt.wrappedValue, range: .distantPast...Date.now) {
                    draft.finishedAt = $0
                }
            } else {
                ReadingDateSheet(title: "Commencé le", date: startedAt.wrappedValue, range: .distantPast...latestStart) {
                    draft.startedAt = $0
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                ToolbarIconButton(
                    title: "Reprendre",
                    systemImage: "arrow.counterclockwise",
                    role: .cancel,
                    action: onRetake
                )
            }
            ToolbarItem(placement: .confirmationAction) {
                ToolbarIconButton(title: "Ajouter", systemImage: "checkmark") {
                    var approved = draft
                    approved.startedAt = draft.startedAt.map { min($0, latestStart) }
                    onSave(approved, renamedSeries)
                }
                .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                .accessibilityIdentifier("review-save")
            }
        }
    }
}

extension ScanReviewPage {
    /// A day picked on a row, as the edit form picks its dates: the calendar
    /// opens on the day shown, and turning the month keeps that day.
    fileprivate func readingDate(
        _ title: LocalizedStringKey,
        icon: String,
        date: Binding<Date>,
        range: ClosedRange<Date>
    ) -> some View {
        // One line: the title and the day, the calendar popping over it.
        DatePicker(selection: date, in: range, displayedComponents: .date) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: icon).foregroundStyle(.secondary)
            }
        }
    }
}

private extension BookDraft {
    /// The draft as the book's page would draw it once saved.
    var asReviewedBook: Book {
        Book(
            id: "review",
            title: title,
            authors: authors,
            format: format,
            publisher: publisher,
            firstPublishedIn: firstPublishedIn,
            synopsis: synopsis,
            genre: genre,
            subgenres: subgenres,
            pageCount: pageCount,
            isbn13: isbn13,
            language: language,
            series: series,
            coverURL: coverURL,
            status: status
        )
    }

    /// Lands a correction made on the review page. The saga is never part of
    /// one: it is the server's answer, and stays as the scan resolved it.
    mutating func apply(_ correction: BookCorrection) {
        if let title = correction.title { self.title = title }
        if let authors = correction.authors { self.authors = authors }
        if let format = correction.format { self.format = format }
        if let change = correction.publisher { publisher = change.value }
        if let change = correction.firstPublishedIn { firstPublishedIn = change.value }
        if let change = correction.synopsis { synopsis = change.value }
        if let change = correction.genre { genre = change.value }
        if let subgenres = correction.subgenres { self.subgenres = subgenres }
        if let change = correction.pageCount { pageCount = change.value }
        if let change = correction.isbn13 { isbn13 = change.value }
        if let change = correction.language { language = change.value }
    }
}

private extension BookCorrection.Change {
    var value: Value? {
        switch self {
        case let .set(value): value
        case .clear: nil
        }
    }
}

#Preview {
    NavigationStack {
        ScanReviewPage(
            draft: BookDraft(
                title: "Le Nom du vent",
                authors: ["Patrick Rothfuss"],
                publisher: "Bragelonne",
                firstPublishedIn: 2007,
                synopsis: "Kvothe raconte sa propre légende.",
                genre: .fantasy,
                subgenres: ["Roman initiatique"],
                pageCount: 662,
                isbn13: "9782352943556",
                series: SeriesMembership(id: "kkc", name: "Chronique du tueur de roi", volume: 1, kind: .main)
            ),
            isSaving: false,
            onSave: { _, _ in },
            onRetake: {}
        )
    }
}
