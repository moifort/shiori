import SwiftUI

/// The sagas as the home draws them, in a rail that scrolls sideways: on two
/// rows once there are four cards to fill them, else on one.
struct SeriesCardRail: View {
    let series: [FollowedSeries]
    let onOpen: (FollowedSeries) -> Void

    private static let cardSize = CGSize(width: 200, height: 128)
    /// Fewer and a second row would stand half empty.
    static let twoRowsFrom = 4

    var body: some View {
        ScrollView(.horizontal) {
            LazyHGrid(
                rows: Array(
                    repeating: GridItem(.fixed(Self.cardSize.height), spacing: 13),
                    count: series.count >= Self.twoRowsFrom ? 2 : 1
                ),
                spacing: 13
            ) {
                ForEach(series) { saga in
                    SeriesShowCard(series: saga.progress, tag: saga.releaseTag, isCompact: true) {
                        onOpen(saga)
                    }
                    .frame(width: Self.cardSize.width, height: Self.cardSize.height)
                    .transition(.homeCard)
                }
            }
            .padding(.horizontal, 20)
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
