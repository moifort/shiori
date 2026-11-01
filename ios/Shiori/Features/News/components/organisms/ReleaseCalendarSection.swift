import SwiftUI

/// "Prochainement": the horizon pills and the list under them — the next 30
/// days, the next six months, or everything announced. A horizon with nothing
/// in it has no pill. Draws what it is given.
struct ReleaseCalendarSection: View {
    let calendar: ReleaseCalendar
    @Binding var horizon: ReleaseHorizon
    let onOpen: (UpcomingRelease) -> Void

    var body: some View {
        let shown = ReleaseHorizon.allCases.filter { !calendar.sections(for: $0).isEmpty }
        let current = shown.contains(horizon) ? horizon : shown.first
        VStack(alignment: .leading, spacing: 12) {
            Text("Prochainement")
                .font(.title2.weight(.bold))
                .padding(.horizontal, 20)
                .accessibilityIdentifier("news-upcoming-header")
            if let current {
                FilterPills(
                    pills: shown.map { .init(id: $0.id, label: $0.label) },
                    selected: current.id,
                    allLabel: nil
                ) { id in
                    horizon = ReleaseHorizon(rawValue: id ?? "") ?? .thirtyDays
                }
                ReleaseList(sections: calendar.sections(for: current), onOpen: onOpen)
            } else {
                Text("Rien d'annoncé")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            }
        }
    }
}

private extension ReleaseHorizon {
    var label: String {
        switch self {
        case .thirtyDays: String(localized: "30 jours")
        case .sixMonths: String(localized: "6 mois")
        case .all: String(localized: "Tout")
        }
    }
}

#Preview("Calendar section") {
    @Previewable @State var horizon = ReleaseHorizon.thirtyDays
    ScrollView {
        ReleaseCalendarSection(
            calendar: ReleaseCalendar(releases: UpcomingRelease.previews, now: .now),
            horizon: $horizon,
            onOpen: { _ in }
        )
    }
    .preferredColorScheme(.dark)
}
