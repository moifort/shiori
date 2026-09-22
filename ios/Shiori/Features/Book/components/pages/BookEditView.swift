import SwiftUI

/// Correcting a book: every fact on the sheet, its place in a saga included.
/// The saga is named, never keyed: the server files the book under the saga the
/// reader already holds by that name, or keys a new one the way a scan would, so
/// a volume the scan missed joins its siblings rather than starting a saga of
/// its own.
///
/// The reading dates are stamped by status changes, and corrected here: only
/// the ones the status carries are shown — a book on the pile was never
/// opened, and only a read one was finished — and none is ever cleared, since
/// moving the book along the pile is what does that.
///
/// The form edits text as the reader sees it and works out the difference only
/// on save, so a field left alone is never sent and one emptied is cleared.
struct BookEditView: View {
    let book: Book
    /// Answers nil once saved, or the message to show when the save failed.
    let onSave: (BookCorrection, Int?) async -> String?
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var authors: String
    @State private var format: BookFormat
    @State private var rating: Int
    @State private var synopsis: String
    @State private var publisher: String
    @State private var year: String
    @State private var pages: String
    /// The running time as typed: "14h30", "14 h", "45 min", "870".
    @State private var duration: String
    @State private var narrators: String
    @State private var genre: BookGenre?
    @State private var language: BookLanguage?
    @State private var subgenres: String
    @State private var isbn: String
    @State private var seriesName: String
    @State private var seriesVolume: String
    @State private var addedAt: Date
    @State private var startedAt: Date
    @State private var finishedAt: Date
    @State private var isSaving = false
    @State private var errorMessage: String?
    /// The reader's subgenre vocabulary, proposed under the field. Empty until
    /// read, and empty for good when the read failed: a convenience, not a need.
    @State private var subgenreSuggestions: [String] = []
    /// The names of the sagas the reader holds, proposed under the series field
    /// so a missed volume joins its siblings under the name they already carry.
    @State private var seriesSuggestions: [String] = []

    init(book: Book, onSave: @escaping (BookCorrection, Int?) async -> String?) {
        self.book = book
        self.onSave = onSave
        _title = State(initialValue: book.title)
        _authors = State(initialValue: book.authors.joined(separator: ", "))
        _format = State(initialValue: book.format)
        _rating = State(initialValue: book.rating ?? 0)
        _synopsis = State(initialValue: book.synopsis ?? "")
        _publisher = State(initialValue: book.publisher ?? "")
        _year = State(initialValue: book.firstPublishedIn.map(String.init) ?? "")
        _pages = State(initialValue: book.pageCount.map(String.init) ?? "")
        _duration = State(initialValue: book.durationMinutes.map(Self.durationText) ?? "")
        _narrators = State(initialValue: book.narrators.joined(separator: ", "))
        _genre = State(initialValue: book.genre)
        _language = State(initialValue: book.language)
        _subgenres = State(initialValue: book.subgenres.joined(separator: ", "))
        _isbn = State(initialValue: book.isbn13 ?? "")
        _seriesName = State(initialValue: book.series?.name ?? "")
        _seriesVolume = State(initialValue: book.series?.volume.map(String.init) ?? "")
        _addedAt = State(initialValue: book.addedAt ?? .now)
        _startedAt = State(initialValue: book.startedAt ?? .now)
        _finishedAt = State(initialValue: book.finishedAt ?? .now)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledField(title: "Titre", icon: "textformat") {
                        TextField("Titre", text: $title, axis: .vertical)
                            .textInputAutocapitalization(.words)
                            .accessibilityIdentifier("edit-title")
                    }
                    LabeledField(title: "Auteurs", icon: "person") {
                        TextField("Auteur", text: $authors, axis: .vertical)
                            .textInputAutocapitalization(.words)
                            .accessibilityIdentifier("edit-authors")
                    }
                    if format == .audiobook {
                        LabeledField(title: "Narrateurs", icon: "person.wave.2") {
                            TextField("Narrateur", text: $narrators, axis: .vertical)
                                .textInputAutocapitalization(.words)
                                .accessibilityIdentifier("edit-narrators")
                        }
                    }
                    MenuPickerRow(
                        title: "Format",
                        icon: "books.vertical",
                        selection: $format,
                        options: BookFormat.allCases,
                        label: { $0.label },
                        image: { Image(systemName: $0.symbol) }
                    )
                    .accessibilityIdentifier("edit-format")
                } footer: {
                    if trimmed(title).isEmpty {
                        Text("Un livre a besoin d'un titre.").foregroundStyle(.red)
                    } else {
                        Text(format == .audiobook
                            ? "Séparez les auteurs et les narrateurs par des virgules."
                            : "Séparez les auteurs par des virgules.")
                    }
                }

                Section {
                    InteractiveStarRating(rating: $rating)
                        .accessibilityIdentifier("edit-rating")
                } header: {
                    Text("Note")
                } footer: {
                    Text(rating == 0
                        ? "Noter un livre le marque comme lu."
                        : "Touchez l'étoile sélectionnée pour retirer la note.")
                }

                if book.addedAt != nil || book.startedAt != nil || book.finishedAt != nil {
                    datesSection
                }

                Section("Résumé") {
                    TextField("Résumé", text: $synopsis, axis: .vertical)
                        .lineLimit(3...12)
                        .accessibilityIdentifier("edit-synopsis")
                }

                Section {
                    LabeledField(title: "Éditeur", icon: "building.2") {
                        TextField("Éditeur", text: $publisher)
                    }
                    LabeledField(title: "Première parution", icon: "calendar") {
                        TextField("Année", text: $year).keyboardType(.numberPad)
                    }
                    // A recording is measured in time, not in pages.
                    if format == .audiobook {
                        LabeledField(title: "Durée", icon: "clock") {
                            TextField("14h30", text: $duration)
                                .keyboardType(.numbersAndPunctuation)
                                .textInputAutocapitalization(.never)
                                .accessibilityIdentifier("edit-duration")
                        }
                    } else {
                        LabeledField(title: "Pages", icon: "doc.plaintext") {
                            TextField("Pages", text: $pages).keyboardType(.numberPad)
                        }
                    }
                    MenuPickerRow(
                        title: "Genre",
                        icon: "theatermasks",
                        selection: $genre,
                        options: [nil] + BookGenre.alphabetical.map(Optional.some),
                        label: { $0?.label ?? String(localized: "Non renseigné") },
                        image: { $0?.image }
                    )
                    .accessibilityIdentifier("edit-genre")
                    Label {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Sous-genres")
                            SubgenreField(text: $subgenres, suggestions: subgenreSuggestions)
                        }
                    } icon: {
                        Image(systemName: "tag").foregroundStyle(.secondary)
                    }
                    MenuPickerRow(
                        title: "Langue",
                        icon: "globe",
                        selection: $language,
                        options: [nil] + BookLanguage.allCases.map(Optional.some),
                        label: { $0?.label ?? String(localized: "Non renseignée") }
                    )
                    .accessibilityIdentifier("edit-language")
                    LabeledField(title: "ISBN", icon: "barcode") {
                        TextField("978…", text: $isbn).keyboardType(.numberPad)
                    }
                } header: {
                    Text("Publication")
                } footer: {
                    if let problem = publicationProblem {
                        Text(problem).foregroundStyle(.red)
                    } else {
                        Text("Séparez les sous-genres par des virgules, trois au plus ; le premier est celui qui s'affiche dans la liste. Un champ vidé est effacé.")
                    }
                }

                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Nom")
                            SeriesNameField(text: $seriesName, suggestions: seriesSuggestions)
                        }
                    } icon: {
                        Image(systemName: "books.vertical").foregroundStyle(.secondary)
                    }
                    if !trimmed(seriesName).isEmpty {
                        LabeledField(title: "Tome", icon: "number") {
                            TextField("Sans numéro", text: $seriesVolume)
                                .keyboardType(.numberPad)
                                .accessibilityIdentifier("edit-series-volume")
                        }
                    }
                } header: {
                    Text("Série")
                } footer: {
                    if let problem = seriesProblem {
                        Text(problem).foregroundStyle(.red)
                    } else {
                        Text("Choisissez une série de votre bibliothèque pour y ranger ce livre avec les autres tomes. Videz le nom pour le sortir de sa série.")
                    }
                }
            }
            .labelStyle(.row)
            .navigationTitle("Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Annuler", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    ToolbarIconButton(title: "Enregistrer", systemImage: "checkmark") { Task { await save() } }
                        .disabled(!isValid || isSaving)
                        .accessibilityIdentifier("edit-save")
                }
            }
            .disabled(isSaving)
            .overlay { if isSaving { ProgressView() } }
            // Both proposal lists in one request. Empty when the read failed,
            // since the proposals are a convenience.
            .task {
                guard let vocabulary = try? await BookAPI.vocabulary() else { return }
                subgenreSuggestions = vocabulary.subgenres
                seriesSuggestions = vocabulary.sagas
            }
            .alert(
                "Impossible d'enregistrer",
                isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .interactiveDismissDisabled(correction != BookCorrection() || (rating == 0 ? nil : rating) != book.rating)
    }

    /// Each picker is bounded by its neighbours, so the form cannot say a book
    /// was finished before it was begun, nor on a day still to come.
    private var datesSection: some View {
        // Never before a date already stored: a server clock a little ahead of
        // the phone's must not leave a picker with an empty range.
        let latest = [Date.now, book.addedAt, book.startedAt, book.finishedAt].compactMap(\.self).max() ?? .now
        return Section {
            if book.addedAt != nil {
                DateField(title: "Ajouté le", icon: "tray.and.arrow.down", date: $addedAt, range: .distantPast...latest)
                    .accessibilityIdentifier("edit-added-at")
            }
            if book.startedAt != nil {
                DateField(
                    title: "Commencé le",
                    icon: "calendar.badge.plus",
                    date: $startedAt,
                    range: .distantPast...(book.finishedAt != nil ? finishedAt : latest)
                )
                .accessibilityIdentifier("edit-started-at")
            }
            if book.finishedAt != nil {
                DateField(
                    title: "Terminé le",
                    icon: "calendar.badge.checkmark",
                    date: $finishedAt,
                    range: (book.startedAt != nil ? startedAt : .distantPast)...latest
                )
                .accessibilityIdentifier("edit-finished-at")
            }
        } header: {
            Text("Dates")
        }
    }

    // MARK: - Validation

    private var isValid: Bool {
        !trimmed(title).isEmpty && publicationProblem == nil && seriesProblem == nil
    }

    /// A volume number the server would refuse, or a new saga it could not key:
    /// a saga is keyed on its first author, and only one the reader already
    /// holds can be joined without one.
    private var seriesProblem: String? {
        guard !trimmed(seriesName).isEmpty else { return nil }
        if !trimmed(seriesVolume).isEmpty, !(1...200).contains(Int(trimmed(seriesVolume)) ?? 0) {
            return String(localized: "Le tome doit être un nombre entre 1 et 200.")
        }
        let held = seriesSuggestions.contains { $0.localizedCaseInsensitiveCompare(trimmed(seriesName)) == .orderedSame }
        if list(authors).isEmpty, !held, trimmed(seriesName) != book.series?.name {
            return String(localized: "Ajoutez un auteur pour créer une nouvelle série.")
        }
        return nil
    }

    /// The first thing the server would refuse, said in the form rather than
    /// after a round trip.
    private var publicationProblem: String? {
        if !trimmed(year).isEmpty, Int(trimmed(year)) == nil {
            return String(localized: "L'année doit être un nombre.")
        }
        if format == .audiobook, !trimmed(duration).isEmpty, Self.minutes(in: duration) == nil {
            return String(localized: "La durée s'écrit comme 14h30, 14 h ou 45 min.")
        }
        if format != .audiobook, !trimmed(pages).isEmpty, (Int(trimmed(pages)) ?? 0) < 1 {
            return String(localized: "Le nombre de pages doit être un nombre positif.")
        }
        if !isbnDigits.isEmpty, !Self.isValidIsbn13(isbnDigits) {
            return String(localized: "L'ISBN doit compter 13 chiffres valides.")
        }
        return nil
    }

    private var isbnDigits: String {
        isbn.filter { !$0.isWhitespace && $0 != "-" }
    }

    /// The same check digit the server verifies, so a typo is caught while the
    /// reader is still looking at it.
    static func isValidIsbn13(_ digits: String) -> Bool {
        guard digits.count == 13, digits.allSatisfy(\.isNumber) else { return false }
        let values = digits.compactMap(\.wholeNumberValue)
        let sum = values.prefix(12).enumerated().reduce(0) { $0 + $1.element * ($1.offset.isMultiple(of: 2) ? 1 : 3) }
        return (10 - sum % 10) % 10 == values[12]
    }

    // MARK: - Changes

    private var correction: BookCorrection {
        var correction = BookCorrection()
        if trimmed(title) != book.title, !trimmed(title).isEmpty { correction.title = trimmed(title) }
        let authorList = list(authors)
        if authorList != book.authors { correction.authors = authorList }
        if format != book.format { correction.format = format }
        correction.publisher = change(from: book.publisher, to: optional(publisher))
        correction.firstPublishedIn = change(from: book.firstPublishedIn, to: Int(trimmed(year)))
        correction.synopsis = change(from: book.synopsis, to: optional(synopsis))
        correction.genre = change(from: book.genre, to: genre)
        let subgenreList = Array(list(subgenres).prefix(3))
        if subgenreList != book.subgenres { correction.subgenres = subgenreList }
        if format == .audiobook {
            correction.durationMinutes = change(from: book.durationMinutes, to: Self.minutes(in: duration))
            let narratorList = list(narrators)
            if narratorList != book.narrators { correction.narrators = narratorList }
        } else {
            correction.pageCount = change(from: book.pageCount, to: Int(trimmed(pages)))
        }
        correction.isbn13 = change(from: book.isbn13, to: isbnDigits.isEmpty ? nil : isbnDigits)
        correction.language = change(from: book.language, to: language)
        correction.series = change(
            from: book.series.map { SeriesPlacement(name: $0.name, volume: $0.volume) },
            to: optional(seriesName).map { SeriesPlacement(name: $0, volume: Int(trimmed(seriesVolume))) }
        )
        if let original = book.addedAt, addedAt != original { correction.addedAt = addedAt }
        if let original = book.startedAt, startedAt != original { correction.startedAt = startedAt }
        if let original = book.finishedAt, finishedAt != original { correction.finishedAt = finishedAt }
        return correction
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        if let failure = await onSave(correction, rating == 0 ? nil : rating) {
            errorMessage = failure
        } else {
            dismiss()
        }
    }

    /// Minutes in a running time as a reader types it: "14h30", "14 h 30",
    /// "14h", "45 min", "45mn", or a bare number of minutes. Nil when it is not
    /// one of those, or not a positive duration.
    static func minutes(in text: String) -> Int? {
        let compact = text.lowercased().filter { !$0.isWhitespace }
        guard !compact.isEmpty else { return nil }
        if let bare = Int(compact) { return bare > 0 ? bare : nil }
        let pattern = /^(?:(\d+)h)?(?:(\d+)(?:min|mn|m)?)?$/
        guard let match = compact.wholeMatch(of: pattern) else { return nil }
        let hours = match.1.flatMap { Int($0) } ?? 0
        let minutes = match.2.flatMap { Int($0) } ?? 0
        guard match.1 != nil || compact.hasSuffix("min") || compact.hasSuffix("mn") || compact.hasSuffix("m") else { return nil }
        let total = hours * 60 + minutes
        return total > 0 ? total : nil
    }

    /// A running time as the field shows it: "14h30", "14h", "45min".
    static func durationText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "\(rest)min" }
        return rest == 0 ? "\(hours)h" : String(format: "%dh%02d", hours, rest)
    }

    private func change<Value: Equatable & Sendable>(from old: Value?, to new: Value?) -> BookCorrection.Change<Value>? {
        guard old != new else { return nil }
        return new.map { .set($0) } ?? .clear
    }

    private func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func optional(_ text: String) -> String? {
        trimmed(text).isEmpty ? nil : trimmed(text)
    }

    private func list(_ text: String) -> [String] {
        text.split(separator: ",").map { trimmed(String($0)) }.filter { !$0.isEmpty }
    }
}

/// A day picked on a form row, with the same icon and label as the sheet's
/// reading row. The day only: the time of day a book was finished is nobody's
/// business, and the picker keeps the one already stored.
private struct DateField: View {
    let title: LocalizedStringKey
    let icon: String
    @Binding var date: Date
    let range: ClosedRange<Date>

    var body: some View {
        Label {
            DatePicker(title, selection: $date, in: range, displayedComponents: .date)
        } icon: {
            Image(systemName: icon).foregroundStyle(.secondary)
        }
    }
}

/// A form row with the same icon and label as the sheet's reading row, and the
/// field trailing where the value was.
private struct LabeledField<Field: View>: View {
    let title: LocalizedStringKey
    let icon: String
    @ViewBuilder let field: Field

    var body: some View {
        Label {
            LabeledContent(title) {
                field.multilineTextAlignment(.trailing)
            }
        } icon: {
            Image(systemName: icon).foregroundStyle(.secondary)
        }
    }
}

#Preview {
    BookEditView(
        book: Book(
            id: "1",
            title: "Le Nom du vent",
            authors: ["Patrick Rothfuss"],
            publisher: "Bragelonne",
            firstPublishedIn: 2007,
            synopsis: "Kvothe raconte sa propre légende.",
            genre: .fantasy,
            subgenres: ["Roman initiatique"],
            pageCount: 662,
            isbn13: "9782352943556",
            status: .read,
            rating: 4
        ),
        onSave: { _, _ in nil }
    )
}
