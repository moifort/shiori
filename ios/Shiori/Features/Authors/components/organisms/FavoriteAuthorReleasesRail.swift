import SwiftUI

/// "Prochaines sorties": what the hearted authors announced, as the covers
/// alone in a rail, the date outlined in each cover's top corner where
/// "Audio" sits elsewhere, and the author, "B. Sanderson", in its foot. The page leaves it out when
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
        let date = release.date.map { NewsShelves.shortDate($0, calendar: calendar) }
            ?? String(localized: "Annoncé")
        return PosterRow.Item(
            book: release.cover,
            label: PosterLabel(caption: Self.person(of: release), cornerTag: date),
            open: { onOpen(release) }
        )
    }

    /// Whom the release is shown for, as "B. Sanderson" so it holds on one
    /// line: the narrator on the Narrators shelf, the author elsewhere.
    static func person(of release: UpcomingRelease) -> String {
        let name = release.source == .narrator
            ? release.narrator ?? release.authors.first
            : release.authors.first ?? release.author?.name
        return NewsPersonTile.shortName(name)
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
