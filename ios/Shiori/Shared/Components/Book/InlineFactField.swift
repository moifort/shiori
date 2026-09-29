import SwiftUI

/// A fact of a book typed straight into its row rather than through a prompt:
/// the publisher, the year, the page count, the ISBN. Each knows its row and
/// how a typed text becomes a correction, with the rules the edit form holds —
/// a text emptied is cleared, a number or an ISBN the server would refuse is
/// never sent.
enum BookFact: String, CaseIterable {
    case publisher
    case firstPublishedIn
    case pageCount
    case isbn13

    var title: LocalizedStringKey {
        switch self {
        case .publisher: "Éditeur"
        case .firstPublishedIn: "Première parution"
        case .pageCount: "Pages"
        case .isbn13: "ISBN"
        }
    }

    var icon: String {
        switch self {
        case .publisher: "building.2"
        case .firstPublishedIn: "calendar"
        case .pageCount: "doc.plaintext"
        case .isbn13: "barcode"
        }
    }

    var keyboard: UIKeyboardType {
        self == .publisher ? .default : .numberPad
    }

    var font: Font? {
        self == .isbn13 ? .callout.monospaced() : nil
    }

    func value(of book: Book) -> String? {
        switch self {
        case .publisher: book.publisher
        case .firstPublishedIn: book.firstPublishedIn.map(String.init)
        case .pageCount: book.pageCount.map(String.init)
        case .isbn13: book.isbn13
        }
    }

    /// The correction a typed text makes to `book`: empty when it changes
    /// nothing, nil when the server would refuse it.
    func correction(from text: String, on book: Book) -> BookCorrection? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var correction = BookCorrection()
        switch self {
        case .publisher:
            correction.publisher = change(from: book.publisher, to: trimmed.isEmpty ? nil : trimmed)
        case .firstPublishedIn:
            guard trimmed.isEmpty || Int(trimmed) != nil else { return nil }
            correction.firstPublishedIn = change(from: book.firstPublishedIn, to: Int(trimmed))
        case .pageCount:
            guard trimmed.isEmpty || (Int(trimmed) ?? 0) >= 1 else { return nil }
            correction.pageCount = change(from: book.pageCount, to: Int(trimmed))
        case .isbn13:
            let digits = trimmed.filter { !$0.isWhitespace && $0 != "-" }
            guard digits.isEmpty || BookEditView.isValidIsbn13(digits) else { return nil }
            correction.isbn13 = change(from: book.isbn13, to: digits.isEmpty ? nil : digits)
        }
        return correction
    }

    private func change<Value: Equatable & Sendable>(from old: Value?, to new: Value?) -> BookCorrection.Change<Value>? {
        guard old != new else { return nil }
        return new.map { .set($0) } ?? .clear
    }
}

/// A row whose value is typed in place, trailing as a stated value sits: the
/// correction leaves when the reader presses return or leaves the field, and
/// a text the server would refuse falls back to what was there.
struct InlineFactField: View {
    let fact: BookFact
    let book: Book
    let onCorrect: (BookCorrection) -> Void

    @State private var text: String
    @FocusState private var focused: Bool

    init(fact: BookFact, book: Book, onCorrect: @escaping (BookCorrection) -> Void) {
        self.fact = fact
        self.book = book
        self.onCorrect = onCorrect
        _text = State(initialValue: fact.value(of: book) ?? "")
    }

    var body: some View {
        Label {
            LabeledContent(fact.title) {
                TextField("Non renseigné", text: $text)
                    .font(fact.font)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(fact.keyboard)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($focused)
                    .onSubmit(commit)
            }
        } icon: {
            Image(systemName: fact.icon).foregroundStyle(.secondary)
        }
        .onChange(of: focused) { _, isFocused in
            if !isFocused { commit() }
        }
        .onChange(of: fact.value(of: book)) { _, value in
            if !focused { text = value ?? "" }
        }
        .accessibilityIdentifier("book-\(fact.rawValue)")
    }

    private func commit() {
        guard let correction = fact.correction(from: text, on: book) else {
            text = fact.value(of: book) ?? ""
            return
        }
        if !correction.isEmpty { onCorrect(correction) }
    }
}
