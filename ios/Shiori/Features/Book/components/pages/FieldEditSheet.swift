import SwiftUI

/// One fact of the book sheet that a tap on its row corrects in place, without
/// going through the whole edit form.
enum BookField: String, Identifiable {
    case publisher
    case firstPublishedIn
    case pageCount
    case isbn13
    case addedAt
    case startedAt
    case finishedAt

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .publisher: "Éditeur"
        case .firstPublishedIn: "Première parution"
        case .pageCount: "Pages"
        case .isbn13: "ISBN"
        case .addedAt: "Ajouté le"
        case .startedAt: "Commencé le"
        case .finishedAt: "Terminé le"
        }
    }

    var isDate: Bool {
        [.addedAt, .startedAt, .finishedAt].contains(self)
    }
}

/// The small prompt behind a tapped row of the book sheet, as the rating has
/// one: the value already there, ready to correct, and a check to save it.
///
/// The same rules as the edit form hold: a text emptied is cleared, a number
/// or an ISBN the server would refuse is said before the round trip, and a
/// date is bounded by its neighbours and never cleared.
struct FieldEditSheet: View {
    let book: Book
    let field: BookField
    /// Answers nil once saved, or the message to show when the save failed.
    let onSave: (BookCorrection) async -> String?
    @Environment(\.dismiss) private var dismiss

    @State private var text: String
    @State private var date: Date
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    init(book: Book, field: BookField, onSave: @escaping (BookCorrection) async -> String?) {
        self.book = book
        self.field = field
        self.onSave = onSave
        let text: String = switch field {
        case .publisher: book.publisher ?? ""
        case .firstPublishedIn: book.firstPublishedIn.map(String.init) ?? ""
        case .pageCount: book.pageCount.map(String.init) ?? ""
        case .isbn13: book.isbn13 ?? ""
        case .addedAt, .startedAt, .finishedAt: ""
        }
        let date: Date? = switch field {
        case .addedAt: book.addedAt
        case .startedAt: book.startedAt
        case .finishedAt: book.finishedAt
        default: nil
        }
        _text = State(initialValue: text)
        _date = State(initialValue: date ?? .now)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if field.isDate {
                    DatePicker("", selection: $date, in: dateRange, displayedComponents: .date)
                        .labelsHidden()
                        .accessibilityIdentifier("field-edit-date")
                } else {
                    TextField(field.title, text: $text)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(field == .publisher ? .default : .numberPad)
                        .textInputAutocapitalization(field == .publisher ? .words : .never)
                        .focused($isFocused)
                        .accessibilityIdentifier("field-edit-text")
                }
                Group {
                    if let problem {
                        Text(problem).foregroundStyle(.red)
                    } else if !field.isDate {
                        Text("Un champ vidé est effacé.").foregroundStyle(.secondary)
                    }
                }
                .font(.footnote)
                .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxHeight: .infinity, alignment: .top)
            .navigationTitle(field.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Annuler", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    AsyncToolbarButton(title: "Enregistrer", systemImage: "checkmark") { await save() }
                        .disabled(correction.isEmpty || problem != nil)
                        .accessibilityIdentifier("field-edit-save")
                }
            }
            .onAppear { isFocused = true }
            .alert(
                "Impossible d'enregistrer",
                isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .presentationDetents([.height(200)])
    }

    /// Bounded as the edit form bounds it: never finished before begun, nor on
    /// a day still to come — nor before a date already stored, so a server
    /// clock a little ahead of the phone's leaves the picker a range.
    private var dateRange: ClosedRange<Date> {
        let latest = [Date.now, book.addedAt, book.startedAt, book.finishedAt].compactMap(\.self).max() ?? .now
        return switch field {
        case .startedAt: .distantPast...(book.finishedAt ?? latest)
        case .finishedAt: (book.startedAt ?? .distantPast)...latest
        default: .distantPast...latest
        }
    }

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isbnDigits: String {
        text.filter { !$0.isWhitespace && $0 != "-" }
    }

    private var problem: String? {
        switch field {
        case .firstPublishedIn where !trimmed.isEmpty && Int(trimmed) == nil:
            String(localized: "L'année doit être un nombre.")
        case .pageCount where !trimmed.isEmpty && (Int(trimmed) ?? 0) < 1:
            String(localized: "Le nombre de pages doit être un nombre positif.")
        case .isbn13 where !isbnDigits.isEmpty && !BookEditView.isValidIsbn13(isbnDigits):
            String(localized: "L'ISBN doit compter 13 chiffres valides.")
        default:
            nil
        }
    }

    private var correction: BookCorrection {
        var correction = BookCorrection()
        let value = trimmed.isEmpty ? nil : trimmed
        switch field {
        case .publisher:
            correction.publisher = change(from: book.publisher, to: value)
        case .firstPublishedIn:
            correction.firstPublishedIn = change(from: book.firstPublishedIn, to: value.flatMap { Int($0) })
        case .pageCount:
            correction.pageCount = change(from: book.pageCount, to: value.flatMap { Int($0) })
        case .isbn13:
            correction.isbn13 = change(from: book.isbn13, to: isbnDigits.isEmpty ? nil : isbnDigits)
        case .addedAt:
            if date != book.addedAt { correction.addedAt = date }
        case .startedAt:
            if date != book.startedAt { correction.startedAt = date }
        case .finishedAt:
            if date != book.finishedAt { correction.finishedAt = date }
        }
        return correction
    }

    private func change<Value: Equatable & Sendable>(from old: Value?, to new: Value?) -> BookCorrection.Change<Value>? {
        guard old != new else { return nil }
        return new.map { .set($0) } ?? .clear
    }

    private func save() async {
        if let failure = await onSave(correction) {
            errorMessage = failure
        } else {
            dismiss()
        }
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        FieldEditSheet(
            book: Book(id: "1", title: "Le Nom du vent", authors: ["Patrick Rothfuss"], publisher: "Bragelonne", status: .read),
            field: .publisher,
            onSave: { _ in nil }
        )
    }
}
