import SwiftUI

/// What follows "Marquer lu", as iOS apps ask for a rating once something is
/// done: the cover with a check, the book named as finished, the stars, then
/// the rating given or passed. The book is marked read either way — passing,
/// or pulling the sheet down, only leaves it unrated.
struct FinishedBookSheet: View {
    let book: Book
    /// The stars given, or nil when the reader passes.
    let onDone: (Double?) -> Void

    @State private var rating: Double = 0
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            BookCover(book: book, width: 96, showsFormatBadge: false)
                .shadow(color: .black.opacity(0.25), radius: 14, y: 8)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 30))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, ReadingStatus.read.tint)
                        .background(Circle().fill(.background).padding(2))
                        .offset(x: 10, y: 10)
                        .symbolEffect(.bounce, value: appeared)
                }
                .padding(.top, 28)
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
            InteractiveStarRating(rating: $rating, allowsUnset: false)
                .padding(.top, 18)
                .accessibilityIdentifier("finished-stars")
            Spacer(minLength: 16)
            VStack(spacing: 6) {
                Button { onDone(rating) } label: {
                    Text("Noter")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.extraLarge)
                .disabled(rating == 0)
                .accessibilityIdentifier("finished-rate")
                Button { onDone(nil) } label: {
                    Text("Passer")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderless)
                .controlSize(.extraLarge)
                .accessibilityIdentifier("finished-skip")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .presentationDetents([.height(460)])
        .presentationDragIndicator(.visible)
        .onAppear { appeared = true }
        .sensoryFeedback(.success, trigger: appeared)
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        FinishedBookSheet(book: Book.preview) { _ in }
    }
}
