import SwiftUI

/// One winner, as the strip and Découvrir's "Prix littéraires" page draw it.
struct AwardWinnerTile: View {
    let winner: AwardWinner
    var width: CGFloat = 84
    let onTapped: () -> Void

    var body: some View {
        Button(action: onTapped) {
            CoverTile(book: winner.cover, caption: winner.caption, width: width, captionTruncation: .middle)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("discover-award-tile")
    }
}

#Preview("Award winner tile") {
    AwardWinnerTile(winner: .preview) {}
}
