import SwiftUI

/// One of the year's counts: its number over its label, two covers leaning out
/// of the top corner, the first cover's colours blurred behind.
struct YearRecapTile: View {
    let tile: YearRecap.Tile

    static let height: CGFloat = 104

    var body: some View {
        ZStack(alignment: .topLeading) {
            ground
            ForEach(Array(tile.covers.enumerated()), id: \.element.id) { index, book in
                BookCover(book: book, width: 52, showsFormatBadge: false)
                    .rotationEffect(.degrees(index == 0 ? 14 : 6))
                    .shadow(color: .black.opacity(0.5), radius: 6, y: 3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .offset(x: index == 0 ? 6 : -22, y: index == 0 ? -14 : -22)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: String(tile.count))
                    .font(.system(size: 30, weight: .heavy))
                    .monospacedDigit()
                Spacer(minLength: 0)
                Label(tile.kind.title, systemImage: tile.kind.systemImage)
                    .font(.system(size: 11, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .frame(height: Self.height)
        .clipShape(.rect(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.18)) }
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
    }

    private var ground: some View {
        Color(white: 0.11)
            .overlay {
                if let url = tile.covers.first?.coverURL {
                    CoverEffectImage(url: url, effect: .backdrop) { Color.clear }
                        .scaleEffect(1.6)
                        .opacity(0.9)
                }
            }
            .overlay { Color.black.opacity(0.35) }
            .clipped()
    }
}

#Preview("Filled") {
    let covers = YearRecap.preview.tiles
    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 10) {
        ForEach(covers) { YearRecapTile(tile: $0) }
    }
    .padding(20)
    .background(.black)
    .preferredColorScheme(.dark)
}
