import SwiftUI

/// The sagas in a rail that scrolls sideways, as every series section draws
/// them — the Library tab, the favourites, an author's page, the home: on two
/// rows once there are four cards to fill them, else on one.
struct SeriesCardRail: View {
    /// One card: the saga's progress, its release tag, what a tap opens.
    struct Card: Identifiable {
        let progress: Dashboard.SeriesProgress
        var tag: String?
        let open: () -> Void
        var id: String { progress.id }
    }

    let cards: [Card]
    /// The page's own margin, inside the rail so the cards scroll to the
    /// edge; zero where the page already pads its rows, as the home does.
    var inset: CGFloat = 20

    static let cardSize = CGSize(width: 200, height: 128)
    /// Fewer and a second row would stand half empty.
    static let twoRowsFrom = 4

    init(cards: [Card], inset: CGFloat = 20) {
        self.cards = cards
        self.inset = inset
    }

    init(series: [FollowedSeries], onOpen: @escaping (FollowedSeries) -> Void) {
        cards = series.map { saga in Card(progress: saga.progress, tag: saga.releaseTag) { onOpen(saga) } }
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHGrid(
                rows: Array(
                    repeating: GridItem(.fixed(Self.cardSize.height), spacing: 13),
                    count: cards.count >= Self.twoRowsFrom ? 2 : 1
                ),
                spacing: 13
            ) {
                ForEach(cards) { card in
                    SeriesShowCard(series: card.progress, tag: card.tag, isCompact: true, onOpen: card.open)
                        .frame(width: Self.cardSize.width, height: Self.cardSize.height)
                        .transition(.homeCard)
                }
            }
            .padding(.horizontal, inset)
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollClipDisabled()
    }
}

#Preview {
    SeriesCardRail(series: SeriesFixtures.followed) { _ in }
        .background(.black)
}
