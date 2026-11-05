import SwiftUI

/// Everything announced, pure: the format pills, then the calendar a month at
/// a time, what is dated to a year alone or not at all, and last the editions
/// awaited that nothing announced yet. With nothing announced, an icon and a
/// sentence say what will come. A tap on a row opens the page its card opens.
struct UpcomingReleasesPage: View {
    let releases: [UpcomingRelease]
    let onOpen: (UpcomingRelease) -> Void

    @State private var format: BookFormat?

    private var shown: [UpcomingRelease] {
        releases.filter { format == nil || $0.format == format }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                FilterPills(
                    pills: NewsFeedLayout.pillFormats.map { .init(id: $0.rawValue, label: $0.pillLabel) },
                    selected: format?.rawValue
                ) { id in
                    format = id.flatMap(BookFormat.init(rawValue:))
                }
                .padding(.top, 4)
                let sections = ReleaseCalendar(releases: shown, now: .now).sections
                if sections.isEmpty {
                    empty
                } else {
                    ReleaseList(sections: sections, onOpen: onOpen)
                        .padding(.top, 8)
                }
            }
            .padding(.bottom, 24)
        }
        .navigationTitle("À venir")
        .accessibilityIdentifier("news-upcoming-list")
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Rien d'annoncé pour l'instant")
                .font(.subheadline.weight(.semibold))
            Text("Les prochaines sorties de vos séries, de vos auteurs et de vos livres guettés s'afficheront ici.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 72)
    }
}

#Preview("À venir") {
    NavigationStack {
        UpcomingReleasesPage(releases: UpcomingRelease.previews, onOpen: { _ in })
    }
    .preferredColorScheme(.dark)
}

#Preview("Rien d'annoncé") {
    NavigationStack {
        UpcomingReleasesPage(releases: [], onOpen: { _ in })
    }
    .preferredColorScheme(.dark)
}
