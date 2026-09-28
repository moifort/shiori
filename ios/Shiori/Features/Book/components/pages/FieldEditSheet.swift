import SwiftUI

/// One fact of the book sheet that a tap on its row corrects in place, without
/// going through the whole edit form.
enum BookField: String, Identifiable {
    case firstPublishedIn
    case pageCount
    case isbn13
    case addedAt
    case startedAt
    case finishedAt

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
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
/// one: the value already there, ready to correct, and a check to save it. A
/// date opens straight on the calendar, and the day tapped is the answer, as a
/// star is for the rating. Turning to another month or year carries the day
/// circled along — the 12th stays the 12th — for the check to save, so a
/// wrong month is fixed without tapping the day again; the cross leaves
/// without a change.
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
                    CalendarDayPicker(
                        date: date,
                        range: dateRange,
                        onMove: { date = $0 },
                        onPick: { day in
                            date = day
                            Task { await save() }
                        }
                    )
                    .accessibilityIdentifier("field-edit-date")
                } else {
                    TextField(field.title, text: $text)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
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
        .presentationDetents([.height(field.isDate ? 480 : 200)])
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

/// The calendar of Reminders: a day tapped is an answer, and turning to
/// another month or year moves the circled day along with the page, keeping its
/// number — clipped to the month's last day and to the range — without
/// answering. SwiftUI's graphical `DatePicker` offers no such difference
/// between a move and an answer, which a sheet saving on change needs.
private struct CalendarDayPicker: UIViewRepresentable {
    let date: Date
    let range: ClosedRange<Date>
    /// The day carried to the month turned to: not an answer yet.
    let onMove: (Date) -> Void
    /// The day tapped: the answer.
    let onPick: (Date) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(picker: self)
    }

    func makeUIView(context: Context) -> UICalendarView {
        let calendarView = UICalendarView()
        calendarView.calendar = .current
        calendarView.availableDateRange = DateInterval(start: range.lowerBound, end: range.upperBound)
        let selection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        selection.selectedDate = Calendar.current.dateComponents([.year, .month, .day], from: date)
        calendarView.selectionBehavior = selection
        calendarView.visibleDateComponents = Calendar.current.dateComponents([.year, .month], from: date)
        context.coordinator.selection = selection
        calendarView.delegate = context.coordinator
        return calendarView
    }

    func updateUIView(_ calendarView: UICalendarView, context: Context) {
        context.coordinator.picker = self
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UICalendarView, context: Context) -> CGSize? {
        let width = proposal.width ?? uiView.intrinsicContentSize.width
        let fitting = uiView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        return CGSize(width: width, height: fitting.height)
    }

    final class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        var picker: CalendarDayPicker
        weak var selection: UICalendarSelectionSingleDate?
        /// The day of the month the reader means, kept across the months turned
        /// so that passing through February does not turn the 31st into the 28th.
        private var day: Int

        init(picker: CalendarDayPicker) {
            self.picker = picker
            day = Calendar.current.component(.day, from: picker.date)
        }

        /// The day tapped, at the time of day already stored, kept within the
        /// range a boundary day could otherwise overstep by a few hours.
        func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            guard let dateComponents, let picked = dated(dateComponents) else { return }
            day = dateComponents.day ?? day
            picker.onPick(picked)
        }

        /// The circled day follows the page to the month turned to.
        func calendarView(_ calendarView: UICalendarView, didChangeVisibleDateComponentsFrom previous: DateComponents) {
            let calendar = Calendar.current
            var components = calendarView.visibleDateComponents
            guard let firstOfMonth = calendar.date(from: DateComponents(year: components.year, month: components.month, day: 1)),
                  let length = calendar.range(of: .day, in: .month, for: firstOfMonth)?.count
            else { return }
            components.day = min(day, length)
            guard let moved = dated(components) else { return }
            selection?.setSelected(calendar.dateComponents([.year, .month, .day], from: moved), animated: true)
            picker.onMove(moved)
        }

        /// The day given, at the time of day already stored, within the range.
        private func dated(_ dateComponents: DateComponents) -> Date? {
            let calendar = Calendar.current
            let time = calendar.dateComponents([.hour, .minute, .second], from: picker.date)
            var components = DateComponents(year: dateComponents.year, month: dateComponents.month, day: dateComponents.day)
            components.hour = time.hour
            components.minute = time.minute
            components.second = time.second
            guard let date = calendar.date(from: components) else { return nil }
            return min(max(date, picker.range.lowerBound), picker.range.upperBound)
        }
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        FieldEditSheet(
            book: Book(id: "1", title: "Le Nom du vent", authors: ["Patrick Rothfuss"], pageCount: 662, status: .read),
            field: .pageCount,
            onSave: { _ in nil }
        )
    }
}
