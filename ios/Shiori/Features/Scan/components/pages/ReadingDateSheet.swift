import SwiftUI

/// Asked when a book being checked is moved to "En cours" or "Lu": the day it
/// was started, or finished, on a calendar opened on today. Closed without an
/// answer, the book keeps today, as the server stamps it.
struct ReadingDateSheet: View {
    let title: LocalizedStringKey
    let range: ClosedRange<Date>
    let onPick: (Date) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date

    init(title: LocalizedStringKey, date: Date, range: ClosedRange<Date>, onPick: @escaping (Date) -> Void) {
        self.title = title
        self.range = range
        self.onPick = onPick
        _date = State(initialValue: date)
    }

    var body: some View {
        NavigationStack {
            DatePicker(title, selection: $date, in: range, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding(.horizontal)
                .frame(maxHeight: .infinity, alignment: .top)
                .accessibilityIdentifier("review-date-picker")
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        ToolbarIconButton(title: "Annuler", systemImage: "xmark", role: .cancel) { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        ToolbarIconButton(title: "Enregistrer", systemImage: "checkmark") {
                            onPick(date)
                            dismiss()
                        }
                        .accessibilityIdentifier("review-date-save")
                    }
                }
        }
        .presentationDetents([.height(480)])
    }
}
