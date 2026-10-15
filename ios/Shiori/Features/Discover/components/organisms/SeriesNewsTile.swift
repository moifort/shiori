import SwiftUI

/// One volume of a saga followed, as the strip and Découvrir's "Nouveautés"
/// page draw it: its day in green once out, in orange while announced.
struct SeriesNewsTile: View {
    let opened: DiscoveryVolume
    var width: CGFloat = 84
    let onTapped: () -> Void
    let onOpenSeries: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        Button(action: onTapped) {
            CoverTile(
                book: opened.cover,
                caption: opened.caption,
                width: width,
                captionTint: opened.isComing ? .orange : .green
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let audibleURL = opened.volume.audibleURL {
                Button("Audible", systemImage: "headphones") { openURL(audibleURL) }
            }
            Button("Série", systemImage: "books.vertical", action: onOpenSeries)
        }
        .accessibilityIdentifier("discover-volume-row")
    }
}

#Preview("Series news tile") {
    SeriesNewsTile(opened: .preview, onTapped: {}, onOpenSeries: {})
}
