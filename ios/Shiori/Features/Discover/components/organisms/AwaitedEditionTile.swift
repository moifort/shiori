import SwiftUI

/// One edition awaited, as the strip and Découvrir's "Bientôt disponible" page
/// draw it.
struct AwaitedEditionTile: View {
    let edition: AwaitedEdition
    var width: CGFloat = 84
    let onTapped: () -> Void

    var body: some View {
        Button(action: onTapped) {
            CoverTile(
                book: edition.cover,
                caption: edition.caption,
                width: width,
                captionTint: edition.stateTint
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("discover-awaited-tile")
    }
}

#Preview {
    AwaitedEditionTile(edition: .preview) {}
        .padding()
}
