import SwiftUI

/// "À venir": everything announced; with nothing announced, an icon and a
/// sentence say what will come. Draws what it is given.
struct ReleaseCalendarSection: View {
    let calendar: ReleaseCalendar
    let onOpen: (UpcomingRelease) -> Void

    var body: some View {
        let sections = calendar.sections
        VStack(alignment: .leading, spacing: 12) {
            Text("À venir")
                .font(.title2.weight(.bold))
                .padding(.horizontal, 20)
                .accessibilityIdentifier("news-upcoming-header")
            if sections.isEmpty {
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
                .padding(.top, 8)
            } else {
                ReleaseList(sections: sections, onOpen: onOpen)
            }
        }
    }
}

#Preview("Calendar section") {
    ScrollView {
        ReleaseCalendarSection(
            calendar: ReleaseCalendar(releases: UpcomingRelease.previews, now: .now),
            onOpen: { _ in }
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Nothing announced") {
    ReleaseCalendarSection(
        calendar: ReleaseCalendar(releases: [], now: .now),
        onOpen: { _ in }
    )
    .preferredColorScheme(.dark)
}
