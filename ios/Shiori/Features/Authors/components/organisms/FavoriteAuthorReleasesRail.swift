import SwiftUI

/// "Prochaines sorties": what the hearted authors announced, as the covers
/// alone in a rail, the date in each cover's foot. The page leaves it out when
/// nothing is announced. A cover opens what the release opens in Actualités.
struct FavoriteAuthorReleasesRail: View {
    let releases: [UpcomingRelease]
    let onOpen: (UpcomingRelease) -> Void
    var calendar: Calendar = .current

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RowHeader(title: "Prochaines sorties", style: .inline).padding(.horizontal, 20)
            PosterRow(items: releases.map(item)) { _ in }
                .contentMargins(.horizontal, 20, for: .scrollContent)
        }
        .accessibilityIdentifier("author-releases")
    }

    private func item(_ release: UpcomingRelease) -> PosterRow.Item {
        PosterRow.Item(
            book: release.cover,
            caption: release.date.map { NewsShelves.shortDate($0, calendar: calendar) }
                ?? String(localized: "Annoncé"),
            open: { onOpen(release) }
        )
    }
}

#if DEBUG
#Preview {
    ScrollView {
        FavoriteAuthorReleasesRail(releases: UpcomingRelease.previews) { _ in }
            .padding(.vertical)
    }
    .background(Color(.systemGroupedBackground))
}
#endif
