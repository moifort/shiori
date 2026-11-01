import SwiftUI

/// "Cette année": the year's four counts in a grid, the first block of the
/// feed. A tile with nothing in it keeps its place, drawn empty.
struct YearRecapSection: View {
    let recap: YearRecap

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cette année")
                .font(.title2.weight(.bold))
                .padding(.horizontal, 20)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                ForEach(recap.tiles) { tile in
                    if tile.count > 0 {
                        YearRecapTile(tile: tile)
                    } else {
                        YearRecapEmptyTile(kind: tile.kind)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

#Preview("Filled") {
    YearRecapSection(recap: .preview)
        .padding(.vertical, 20)
        .background(.black)
        .preferredColorScheme(.dark)
}

#Preview("Nothing yet") {
    YearRecapSection(recap: .empty)
        .padding(.vertical, 20)
        .background(.black)
        .preferredColorScheme(.dark)
}

#Preview("One empty") {
    YearRecapSection(recap: YearRecap(tiles: YearRecap.preview.tiles.dropLast() + [
        .init(kind: .awaitedAvailable, count: 0, covers: []),
    ]))
    .padding(.vertical, 20)
    .background(.black)
    .preferredColorScheme(.dark)
}
