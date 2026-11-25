import SwiftUI

/// An uncertain row set beside the book the library holds, for the reader to
/// say whether they are one. Pure and previewable.
struct GoodreadsSameBookSheet: View {
    let row: GoodreadsRow
    var onSame: () -> Void
    var onDifferent: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Est-ce le même livre ?")
                .font(.title3.bold())
                .padding(.top, 24)
            HStack(alignment: .top, spacing: 16) {
                side(label: "Dans Shiori", book: row.heldCover ?? row.cover, title: row.heldTitle ?? row.title)
                side(label: "Sur Goodreads", book: row.cover, title: row.title)
            }
            .padding(.horizontal, 24)
            Spacer(minLength: 0)
            Text("Le même : votre livre prend la note et la date de Goodreads.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            VStack(spacing: 12) {
                Button(action: onSame) {
                    Text("Même livre").frame(maxWidth: .infinity)
                }
                .buttonStyle(.actionWide)
                .controlSize(.large)
                Button(action: onDifferent) {
                    Text("Deux livres différents").frame(maxWidth: .infinity)
                }
                .buttonStyle(.actionGlass)
                .controlSize(.large)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .presentationDetents([.height(560)])
    }

    private func side(label: LocalizedStringKey, book: Book, title: String) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
            BookCover(book: book, width: 96, showsFormatBadge: false)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(verbatim: book.authors.first ?? "")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        GoodreadsSameBookSheet(row: GoodreadsPreview.preview.uncertainRows[0], onSame: {}, onDifferent: {})
    }
    .environment(\.colorScheme, .dark)
}
