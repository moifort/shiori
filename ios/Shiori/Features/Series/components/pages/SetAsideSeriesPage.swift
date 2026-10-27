import SwiftUI

/// "Mises de côté": the sagas the reader stopped following, as the cards of
/// "Toutes les séries" greyed, under a sentence saying what that means. A tap
/// opens the saga; a long press follows it again.
struct SetAsideSeriesPage: View {
    let series: [FollowedSeries]
    let isLoading: Bool
    let onOpen: (FollowedSeries) -> Void
    let onFollow: (FollowedSeries) -> Void

    private let columns = [GridItem(.flexible(), spacing: 13), GridItem(.flexible(), spacing: 13)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Ces séries ne sont plus suivies : elles n'apparaissent ni dans « À suivre », ni dans les sorties, ni sur l'accueil. Leurs tomes restent dans la bibliothèque.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                LazyVGrid(columns: columns, spacing: 13) {
                    ForEach(series) { saga in
                        SeriesShowCard(series: saga.progress, isCompact: true, isSetAside: true) { onOpen(saga) }
                            .frame(height: 128)
                            .contextMenu {
                                Button("Suivre à nouveau", systemImage: "bell") { onFollow(saga) }
                            }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Mises de côté")
        .navigationBarTitleDisplayMode(.large)
        .overlay {
            if series.isEmpty, isLoading { ProgressView() }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        SetAsideSeriesPage(series: SeriesFixtures.followed, isLoading: false, onOpen: { _ in }, onFollow: { _ in })
    }
}
#endif
