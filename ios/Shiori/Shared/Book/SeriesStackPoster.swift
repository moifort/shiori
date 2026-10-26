import SwiftUI

/// A saga as a poster among books: its last volume held in front, carrying the
/// line, and two volumes before it peeking above, darker the further back —
/// "Coups de cœur" draws a hearted saga this way in its rail, so it reads at a
/// glance as several books. It takes a book's place exactly: the volumes
/// behind rise above it, into the space its row leaves over the covers.
struct SeriesStackPoster: View {
    let saga: FollowedSeries
    var width: CGFloat = 102

    /// How far above the front cover the stack rises.
    static let rise: CGFloat = 12

    var body: some View {
        ZStack(alignment: .top) {
            ForEach(Array(behind.enumerated()), id: \.offset) { index, book in
                let depth = CGFloat(behind.count - index)
                PosterCover(book: book, caption: "", width: width, showsEditionTags: false)
                    .scaleEffect(1 - 0.07 * depth, anchor: .top)
                    .brightness(-0.25 * depth)
                    .offset(y: -Self.rise / 2 * depth)
            }
            if let front {
                PosterCover(book: front, label: PosterLabel(caption: saga.volumeCountText), width: width)
            }
        }
        .frame(width: width, height: width * 1.5, alignment: .top)
    }

    /// The first volume that has a cover, else the first held: the saga keeps
    /// one face however many volumes join it.
    private var front: Book? {
        saga.volumes.first(where: { $0.coverURL != nil }) ?? saga.volumes.first
    }

    /// Up to two volumes after the front one, the furthest back first.
    private var behind: [Book] {
        guard let front else { return [] }
        let others = saga.volumes.filter { $0.id != front.id }
        let covered = others.filter { $0.coverURL != nil }
        return Array((covered.isEmpty ? others : covered).prefix(2).reversed())
    }
}

extension FollowedSeries {
    /// "7 tomes": how many volumes the reader holds, the line of its stack.
    var volumeCountText: String {
        ownedCount == 1 ? String(localized: "1 tome") : String(localized: "\(ownedCount) tomes")
    }
}

#Preview {
    HStack(alignment: .bottom, spacing: 13) {
        SeriesStackPoster(saga: SeriesFixtures.followed[0])
        PosterCover(book: .preview, label: PosterLabel(caption: "Lu en 2026"))
    }
    .padding()
    .padding(.top, SeriesStackPoster.rise)
    .background(.black)
}
