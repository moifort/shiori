import SwiftUI

/// The prompt behind "Noter ce livre". It says up front that a rating marks the
/// book read, because the server does exactly that and a reader rating a book on
/// their pile would otherwise see it jump shelves with no warning.
///
/// A tap on a star is the answer: there is nothing else to fill in, so a
/// separate confirm button would only be a second tap for the same decision.
struct RatingPromptView: View {
    let onRate: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var rating = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Noter un livre le marque comme lu.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                InteractiveStarRating(rating: $rating, allowsUnset: false)
                    .accessibilityIdentifier("rating-prompt-stars")
            }
            .padding()
            .frame(maxHeight: .infinity, alignment: .top)
            .navigationTitle("Noter ce livre")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Annuler", systemImage: "xmark", role: .cancel) { dismiss() }
                }
            }
            .onChange(of: rating) { _, stars in
                if stars > 0 { onRate(stars) }
            }
        }
        .presentationDetents([.height(200)])
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        RatingPromptView(onRate: { _ in })
    }
}
