import SwiftUI

/// "Par genre": a tile per genre, two by row, its name over how many books, on
/// the genre's own colour, the cover of its last book tilted in the corner.
struct GenreTileGrid: View {
    let genres: [GenreShelf]
    let onOpen: (BookGenre) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(genres) { shelf in
                Button { onOpen(shelf.genre) } label: { tile(shelf) }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, 20)
    }

    private func tile(_ shelf: GenreShelf) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(shelf.genre.label)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(shelf.count == 1 ? String(localized: "1 livre") : String(localized: "\(shelf.count) livres"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.75))
        }
        .foregroundStyle(.white)
        .padding(.leading, 14)
        .padding(.trailing, 44)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .topLeading)
        .background {
            LinearGradient(
                colors: [shelf.genre.tint.opacity(0.5), shelf.genre.tint.opacity(0.14)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .background(Color(white: 0.11))
        }
        .overlay(alignment: .bottomTrailing) {
            if let url = shelf.coverURL {
                CoverImage(url: url) { Color.clear } fallback: { Color.clear }
                    .frame(width: 46, height: 69)
                    .clipShape(.rect(cornerRadius: 4))
                    .shadow(color: .black.opacity(0.5), radius: 7, y: 6)
                    .rotationEffect(.degrees(12))
                    .offset(x: 6, y: 14)
            }
        }
        .clipShape(.rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
        }
        .contentShape(.rect(cornerRadius: 18))
    }
}

#Preview {
    GenreTileGrid(genres: [
        GenreShelf(genre: .scienceFiction, count: 62),
        GenreShelf(genre: .fantasy, count: 54),
        GenreShelf(genre: .adventure, count: 31),
        GenreShelf(genre: .literaryFiction, count: 23),
    ]) { _ in }
        .background(.black)
}
