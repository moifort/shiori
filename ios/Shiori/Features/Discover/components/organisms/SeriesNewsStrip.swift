import SwiftUI

/// "Nouveautés séries": the volumes of the sagas followed, read and heard, as
/// a strip of covers like the editions awaited — the ones just out first with
/// their day in green, then the ones announced with theirs in orange. A tap
/// opens the volume's page; a long press offers its saga, and a recording's
/// page on Audible.
struct SeriesNewsStrip: View {
    let volumes: [DiscoveryVolume]
    let onTapped: (DiscoveryVolume) -> Void
    let onOpenSeries: (SagaDiscovery) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(volumes) { opened in
                    SeriesNewsTile(
                        opened: opened,
                        onTapped: { onTapped(opened) },
                        onOpenSeries: { onOpenSeries(opened.saga) }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .listRowInsets(EdgeInsets())
    }
}

#Preview("Series news strip") {
    List {
        SeriesNewsStrip(volumes: DiscoveryFeed.preview.seriesNews, onTapped: { _ in }, onOpenSeries: { _ in })
    }
}
