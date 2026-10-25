import SwiftUI

/// What follows "Marquer lu", as Fitness asks for the effort once a workout is
/// done: the cover, the book named as finished and the stars, between a close
/// button that cancels and a check that marks the book read. Only the check
/// finishes it, rated when stars were given: the cross, or pulling the sheet
/// down, leaves the book as it was — a button tapped by mistake must not end a
/// reading.
struct FinishedBookSheet: View {
    let book: Book
    /// The book is finished: the stars given, or nil when none were.
    let onDone: (Double?) -> Void
    /// The reader changed their mind: the book stays where it was.
    let onCancel: () -> Void

    @State private var rating: Double = 0
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            content
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        ToolbarIconButton(title: "Annuler", systemImage: "xmark", role: .cancel) {
                            onCancel()
                        }
                        .accessibilityIdentifier("finished-cancel")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        ToolbarIconButton(title: "Marquer lu", systemImage: "checkmark") {
                            onDone(rating == 0 ? nil : rating)
                        }
                        .accessibilityIdentifier("finished-done")
                    }
                }
        }
        .presentationDetents([.height(460)])
        .presentationDragIndicator(.hidden)
        .onAppear { appeared = true }
        .sensoryFeedback(.success, trigger: appeared)
    }

    private var content: some View {
        VStack(spacing: 0) {
            BookCover(book: book, width: 116, showsFormatBadge: false)
                .shadow(color: .black.opacity(0.25), radius: 14, y: 8)
                .padding(.top, 4)
            Text("Lecture terminée")
                .font(.title2.weight(.bold))
                .padding(.top, 22)
            // The title then the question: "de" before a title elides or
            // not with its first letter, which a sentence cannot know.
            Text(book.title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.top, 4)
                .padding(.horizontal, 24)
            Text("Qu'en avez-vous pensé ?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            // White, as the rest of the sheet: the app's yellow stars stood out of it.
            InteractiveStarRating(rating: $rating, allowsUnset: false, scale: 1.25)
                .padding(.top, 16)
                .accessibilityIdentifier("finished-stars")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        FinishedBookSheet(book: Book.preview, onDone: { _ in }, onCancel: {})
    }
}
