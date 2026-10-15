import SwiftUI

/// Découvrir's strip of the latest award winners the reader does not hold,
/// drawn as the editions awaited are: covers that scroll sideways, the prize
/// and its year under each.
struct AwardWinnersStrip: View {
    let winners: [AwardWinner]
    let onTapped: (AwardWinner) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(winners) { winner in
                    AwardWinnerTile(winner: winner) { onTapped(winner) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .listRowInsets(EdgeInsets())
    }
}

#Preview("Award winners strip") {
    List {
        AwardWinnersStrip(winners: AwardSection.previews.flatMap(\.winners)) { _ in }
    }
}
