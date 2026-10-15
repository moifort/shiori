import SwiftUI

/// Découvrir's strip of the editions awaited in one format, drawn as the
/// friends' favourites are: covers that scroll sideways, the ones out first
/// with "Disponible" in green under them, the date of the ones announced in
/// orange. No title: the cover says it.
struct AwaitedEditionsStrip: View {
    let editions: [AwaitedEdition]
    let onTapped: (AwaitedEdition) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(editions) { edition in
                    AwaitedEditionTile(edition: edition) { onTapped(edition) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .listRowInsets(EdgeInsets())
    }
}

#Preview {
    List {
        AwaitedEditionsStrip(editions: DiscoveryFeed.preview.awaitedSoon) { _ in }
    }
}
