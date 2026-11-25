import SwiftUI

/// An import under way, from the settings: the books go in first, then their
/// covers are sought; the reader may close the page and the work goes on.
/// Pure and previewable.
struct GoodreadsProgressPage: View {
    let covers: [Book]
    /// Books written so far, of the total.
    let done: Int
    let total: Int
    let progress: Double
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            HStack(spacing: -22) {
                ForEach(Array(covers.prefix(5).enumerated()), id: \.offset) { index, book in
                    BookCover(book: book, width: 70, showsFormatBadge: false)
                        .rotationEffect(.degrees(Double(index - 2) * 6))
                        .shadow(color: .black.opacity(0.5), radius: 9, y: 8)
                }
            }
            Text("\(done) sur \(total)")
                .font(.largeTitle.bold())
                .monospacedDigit()
                .padding(.top, 36)
            ProgressView(value: progress)
                .tint(.white)
                .padding(.top, 16)
            Text("Vos livres arrivent dans la bibliothèque au fil de l'import. Vous pouvez fermer cet écran : l'import continue.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 16)
            Spacer()
        }
        .padding(.horizontal, 32)
        .navigationTitle("Import Goodreads")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel, action: onClose)
            }
        }
        .accessibilityIdentifier("goodreads-progress")
    }
}

#Preview {
    NavigationStack {
        GoodreadsProgressPage(
            covers: GoodreadsPreview.preview.rows.map(\.cover),
            done: 640,
            total: 1424,
            progress: 0.45,
            onClose: {}
        )
    }
    .environment(\.colorScheme, .dark)
}
