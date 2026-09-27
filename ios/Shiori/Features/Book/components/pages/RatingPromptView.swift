import SwiftUI

/// The prompt behind "Noter ce livre" and "Noter cette série". For a book it
/// says up front that a rating marks the book read, because the server does
/// exactly that and a reader rating a book on their pile would otherwise see it
/// jump shelves with no warning. A saga's rating touches none of its volumes, so
/// its prompt has nothing to warn about.
///
/// Something already rated opens on its stars, and the prompt then corrects the
/// rating rather than gives one: the warning has nothing left to warn about.
///
/// A tap on a star is the answer: there is nothing else to fill in, so a
/// separate confirm button would only be a second tap for the same decision.
/// Taking a rating back is its own button, offered only where the caller can
/// honour it: a saga's rating can be withdrawn, a book's cannot.
struct RatingPromptView: View {
    enum Subject { case book, series }

    var subject: Subject = .book
    let current: Int?
    var onRemove: (() -> Void)? = nil
    let onRate: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var rating: Int

    init(
        subject: Subject = .book,
        current: Int? = nil,
        onRemove: (() -> Void)? = nil,
        onRate: @escaping (Int) -> Void
    ) {
        self.subject = subject
        self.current = current
        self.onRemove = onRemove
        self.onRate = onRate
        _rating = State(initialValue: current ?? 0)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if current == nil, subject == .book {
                    Text("Noter un livre le marque comme lu.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                InteractiveStarRating(rating: $rating, allowsUnset: false)
                    .accessibilityIdentifier("rating-prompt-stars")
                if current != nil, let onRemove {
                    Button("Retirer la note", role: .destructive, action: onRemove)
                        .font(.subheadline)
                        .accessibilityIdentifier("rating-prompt-remove")
                }
            }
            .padding()
            .frame(maxHeight: .infinity, alignment: .top)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Annuler", systemImage: "xmark", role: .cancel) { dismiss() }
                }
            }
            .onChange(of: rating) { _, stars in
                if stars > 0, stars != current { onRate(stars) }
            }
        }
        .presentationDetents([.height(current != nil && onRemove != nil ? 240 : 200)])
    }

    private var title: LocalizedStringKey {
        switch (subject, current) {
        case (.book, nil): "Noter ce livre"
        case (.series, nil): "Noter cette série"
        case (_, .some): "Modifier la note"
        }
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        RatingPromptView(onRate: { _ in })
    }
}
