import SwiftUI

/// One saga in the Series shelf's mosaic, drawn as the library's mosaic draws
/// a book: its opening volume's cover alone, edge to edge with its neighbours.
/// Over its foot, the heart of a loved saga on the left and, on the right,
/// where the reader stands on it and how many volumes they hold — of how many,
/// once the catalogue says — where the Photos app counts an album.
struct SeriesTile: View {
    let entry: FollowedSeries
    let width: CGFloat
    /// Off where a filter already says which state every saga is in.
    var showsState = true

    var body: some View {
        BookCover(book: cover, width: width, showsFormatBadge: false, cornerRadius: 0)
            .overlay(alignment: .bottom) {
                MosaicGlyphs {
                    if entry.opinion?.favorite == true { Image(systemName: "heart.fill") }
                } trailing: {
                    HStack(spacing: 3) {
                        if showsState, let state = entry.state {
                            Image(systemName: state.symbol)
                                .accessibilityLabel(Text(state.label))
                        }
                        Text(verbatim: countLabel).monospacedDigit()
                    }
                }
            }
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(entry.name))
    }

    /// The saga's opening volume held. A saga without any on the row — a
    /// snapshot from before they were asked for — draws its name.
    private var cover: Book {
        entry.volumes.first
            ?? Book(id: entry.seriesId, title: entry.name, authors: entry.author.map { [$0] } ?? [], status: .toRead)
    }

    /// "3/7" when the catalogue knows volumes out that the reader lacks, "3"
    /// otherwise. The volumes announced but not out yet are not counted.
    private var countLabel: String {
        let published = entry.strip.filter {
            if case let .missing(_, _, _, forthcoming, _, _) = $0 { !forthcoming } else { true }
        }
        let held = published.filter { if case .owned = $0 { true } else { false } }.count
        return entry.isCatalogued && published.count > held
            ? "\(held)/\(published.count)"
            : "\(entry.ownedCount)"
    }
}
